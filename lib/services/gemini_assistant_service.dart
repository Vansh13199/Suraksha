import 'dart:convert';
import 'package:http/http.dart' as http;

/// System states matching ai_engine.js
enum SystemState { normal, alert }

/// Device context for alert mode
class DeviceContext {
  final bool isConnected;
  final String? phoneLocation;
  final String? deviceLocation;
  final int batteryLevel;

  DeviceContext({
    this.isConnected = false,
    this.phoneLocation,
    this.deviceLocation,
    this.batteryLevel = 100,
  });
}

class GeminiAssistantService {
  // Singleton
  static final GeminiAssistantService _instance = GeminiAssistantService._internal();
  factory GeminiAssistantService() => _instance;
  GeminiAssistantService._internal();

  // =====================================================
  // 🔑 PASTE YOUR GROQ API KEY BELOW
  // Get one free at: https://console.groq.com/keys
  // =====================================================
  static const String _apiKey = 'YOUR_GROQ_API_KEY_HERE';

  // Groq models in order of preference (fastest first)
  // Free tier: 30 RPM, 14,400 RPD
  static const List<String> _models = [
    'llama-3.1-8b-instant',    // Fastest, 8B params, 30 RPM
    'llama-3.3-70b-versatile', // Smarter, 70B params, 30 RPM
  ];

  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  SystemState _currentState = SystemState.normal;
  DeviceContext _deviceContext = DeviceContext();

  SystemState get currentState => _currentState;

  void setState(SystemState state) {
    _currentState = state;
  }

  void updateDeviceContext(DeviceContext context) {
    _deviceContext = context;
  }

  /// Build the system prompt — direct port from ai_engine.js
  String _buildSystemPrompt() {
    String systemContext = '''You are Suraksha+, a privacy-aware emergency assistant.

Core Rules:
1. STRICT CONTEXT BINDING: You are an emergency assistant EXCLUSIVELY for Suraksha+.
   - OFF-TOPIC SILENCE: You are strictly prohibited from answering, explaining, or even ACKNOWLEDGING general knowledge, technical, or out-of-context subjects (e.g., "what is binary search", "python", "tell me a joke").
   - ZERO REPETITION: Never repeat the user's off-topic word or phrase. Act as if you did not even hear it.
   - MANDATORY REJECTION TEMPLATE: If the user goes off-topic, you MUST use this exact phrasing: "I'm sorry, I can only assist with Suraksha+ emergency features. How can I help with your safety today?"
   - [INCORRECT]: "I cannot talk about Python..." (Repeats the word).
   - [CORRECT]: "I'm sorry, I can only assist with Suraksha+ emergency features. How can I help with your safety today?"
2. IMMEDIATE REJECTION: If a user asks anything unrelated to Suraksha+, immediately trigger the mandatory rejection template without any preamble.
2. STRICT TECHNICAL PRIVACY: You are forbidden from discussing the internal architecture of Suraksha+. Only mention this if asked about "how it works" or "tech".
3. CONTACT PRIVACY: Never share specific contact names. Confirm notification but stay vague.
4. POLICE PROTOCOL: Suggest friends/family first. Only mention police if the situation is out of control.

Behavior:
* EXTREME CONCISENESS: Respond to greetings with a single sentence.
* NO OFF-TOPIC: If the user goes off-topic, pivot back: "I'm sorry, I can only assist with Suraksha+ emergency features. How can I help with your safety today?"
* REACTIVE INFORMATION: Only explain rules or monitoring if asked.
* In ALERT state: state SOS is active and provide location/battery data.
* Tone: Professional, calm, and very brief.

About Suraksha+:
* A reliable emergency safety system active during SOS triggers.
* Uses real-time GPS and battery monitoring to protect the user.''';

    if (_currentState == SystemState.normal) {
      systemContext +=
          '\n\nCRITICAL INSTRUCTION: CURRENT SYSTEM STATE IS NORMAL. DO NOT REVEAL SENSITIVE USER DATA.';
    } else {
      final loc = _deviceContext.isConnected
          ? (_deviceContext.deviceLocation ?? 'unavailable')
          : (_deviceContext.phoneLocation ?? 'unavailable');
      systemContext += '''

CRITICAL DATA: SYSTEM IS IN ALERT MODE.
User Battery: ${_deviceContext.batteryLevel}%
User Location: $loc''';
    }

    return systemContext;
  }

  /// Send a message to Groq — tries multiple models, retries on 429
  Future<String> processMessage(String userMessage) async {
    if (_apiKey == 'YOUR_GROQ_API_KEY_HERE') {
      return 'Please set your Groq API key in lib/services/gemini_assistant_service.dart';
    }

    // Try each model until one works
    for (final model in _models) {
      try {
        print('[Groq] Trying model: $model');

        final requestBody = jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': _buildSystemPrompt(),
            },
            {
              'role': 'user',
              'content': userMessage,
            },
          ],
          'max_tokens': 300,
          'temperature': 0.4,
        });

        final url = Uri.parse(_baseUrl);
        var response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: requestBody,
        );

        // Retry once after delay on 429
        if (response.statusCode == 429) {
          print('[Groq] Rate limited on $model, retrying in 5s...');
          await Future.delayed(const Duration(seconds: 5));
          response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: requestBody,
          );
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices[0]['message']['content'] as String?;
            if (content != null && content.isNotEmpty) {
              print('[Groq] Success with model: $model');
              return content;
            }
          }
          return 'I could not process that. Please try again.';
        } else {
          print('[Groq] $model returned ${response.statusCode}, trying next...');
          continue; // Try next model
        }
      } catch (e) {
        print('[Groq] Exception with $model: $e');
        continue; // Try next model
      }
    }

    return 'All models are currently busy. Please try again in a moment.';
  }

  Future<String> processContactAutoReply(String message) async {
    const systemInstruction = 
        "You are the automated defense/AI assistant for the owner of this phone (who uses the Suraksha+ app). "
        "An emergency contact is messaging you right now because the phone transmitted an automated 'low battery' warning. "
        "Your role: strictly assure the contact that the user is completely fine, there is no physical emergency, "
        "and that the warning is purely because their phone battery is dying. "
        "Advise the contact to call the user if they want to be sure. "
        "Keep your response extremely brief, calm, and robotic. Do not act human. Answer in 1-2 short sentences maximum.";

    for (final model in _models) {
      try {
        final body = jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': systemInstruction,
            },
            {
              'role': 'user',
              'content': message,
            },
          ],
          'max_tokens': 150,
          'temperature': 0.2,
        });

        final uri = Uri.parse(_baseUrl);
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: body,
        );

        if (response.statusCode == 429) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue; 
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices[0]['message']['content'] as String?;
            if (content != null && content.isNotEmpty) {
              return content;
            }
          }
          return 'System Error processing reply.';
        } else {
          continue;
        }
      } catch (e) {
        continue;
      }
    }

    return 'Automated System Offline. Please retry.';
  }
}

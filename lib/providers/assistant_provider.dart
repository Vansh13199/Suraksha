import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/gemini_assistant_service.dart';
import '../services/chat_database_helper.dart';
import '../main.dart'; // To access flutterLocalNotificationsPlugin
import 'package:provider/provider.dart';
import 'sos_provider.dart';

class ChatMessage {
  final int? id;
  final String text;
  final bool isUser;
  final bool isSystem;
  final DateTime timestamp;

  ChatMessage({
    this.id,
    required this.text,
    this.isUser = false,
    this.isSystem = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) ChatDatabaseHelper.columnId: id,
      ChatDatabaseHelper.columnText: text,
      ChatDatabaseHelper.columnIsUser: isUser ? 1 : 0,
      ChatDatabaseHelper.columnIsSystem: isSystem ? 1 : 0,
      ChatDatabaseHelper.columnTimestamp: timestamp.millisecondsSinceEpoch,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map[ChatDatabaseHelper.columnId],
      text: map[ChatDatabaseHelper.columnText],
      isUser: map[ChatDatabaseHelper.columnIsUser] == 1,
      isSystem: map[ChatDatabaseHelper.columnIsSystem] == 1,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map[ChatDatabaseHelper.columnTimestamp]),
    );
  }
}

class AssistantProvider extends ChangeNotifier {
  final GeminiAssistantService _gemini = GeminiAssistantService();
  final ChatDatabaseHelper _dbHelper = ChatDatabaseHelper.instance;

  final List<ChatMessage> _messages = [];

  bool _isOpen = false;
  bool _isTyping = false;
  bool _isLoading = true;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isOpen => _isOpen;
  bool get isTyping => _isTyping;
  bool get isLoading => _isLoading;
  SystemState get currentState => _gemini.currentState;

  AssistantProvider() {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    final loadedMessages = await _dbHelper.getAllMessages();
    
    if (loadedMessages.isEmpty) {
      // First time using chat, add default greeting
      final initialMessage = ChatMessage(
        text: 'Hello! I am your Suraksha+ assistant. How can I help you today?',
      );
      await _addAndSaveMessage(initialMessage);
    } else {
      _messages.addAll(loadedMessages);
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _addAndSaveMessage(ChatMessage message) async {
    _messages.add(message);
    notifyListeners();
    // Save to SQLite
    final id = await _dbHelper.insertMessage(message);
    // Ideally update model with ID, but we only load mostly.
  }

  void toggleChat() {
    _isOpen = !_isOpen;
    notifyListeners();
  }

  void openChat() {
    _isOpen = true;
    notifyListeners();
  }

  void closeChat() {
    _isOpen = false;
    notifyListeners();
  }

  /// Send a user message and get AI response
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message
    await _addAndSaveMessage(ChatMessage(text: text, isUser: true));
    
    _isTyping = true;
    notifyListeners();

    // Get AI response
    final response = await _gemini.processMessage(text);

    _isTyping = false;
    await _addAndSaveMessage(ChatMessage(text: response));
  }


  /// Triggered when ESP32 reports low battery
  void triggerLowBatteryAlert(int batteryLevel) async {
    if (_gemini.currentState == SystemState.alert) return;

    _gemini.setState(SystemState.alert);
    _gemini.updateDeviceContext(DeviceContext(
      batteryLevel: batteryLevel,
      isConnected: true,
    ));

    // Automatically map low battery to an actual SOS session
    final currentContext = navigatorKey.currentContext;
    if (currentContext != null) {
      try {
        final sosProvider = currentContext.read<SosProvider>();
        if (!sosProvider.isSosActive) {
          sosProvider.handleAppTriggeredSos(isLowBattery: true);
        }
      } catch (e) {
        print("Failed to auto-trigger SOS from low battery: $e");
      }
    }

    await _addAndSaveMessage(ChatMessage(
      text: '⚠️ Low battery detected ($batteryLevel%). Guidance mode active.',
      isSystem: true,
    ));

    // Note: Local push notification and chat auto-open REMOVED for the sender 
    // to comply with the "Recipient-Only Data" rule.
    notifyListeners();
  }

  /// Triggered when SOS is activated
  void triggerSosAlert({double? lat, double? lon}) async {
    _gemini.setState(SystemState.alert);

    // Note: Local messages and chat auto-open REMOVED for the sender
    // to comply with the "Recipient-Only Data" rule.
    notifyListeners();
  }

  /// Restore to normal state, turning off SOS if active
  void restoreNormal([BuildContext? context]) async {
    if (_gemini.currentState == SystemState.normal) return;

    _gemini.setState(SystemState.normal);

    if (context != null) {
      try {
        // Need to import Provider and SosProvider at top of file
        final sosProvider = context.read<SosProvider>();
        if (sosProvider.isSosActive) {
          sosProvider.deactivateSos();
        }
      } catch (e) {
        print("Failed to deactivate SOS: $e");
      }
    }

    await _addAndSaveMessage(ChatMessage(
      text: '✅ System restored to NORMAL state. Privacy locks engaged and SOS disarmed.',
      isSystem: true,
    ));
    notifyListeners();
  }

  /// Manually force alert state for responder dashboard visibility
  void setAlertStateForResponder() {
    if (_gemini.currentState != SystemState.alert) {
      _gemini.setState(SystemState.alert);
      notifyListeners();
    }
  }

  /// Clear the database and memory
  Future<void> clearHistory() async {
    await _dbHelper.clearHistory();
    _messages.clear();
    
    final initialMessage = ChatMessage(
        text: 'Hello! I am your Suraksha+ assistant. How can I help you today?',
    );
    await _addAndSaveMessage(initialMessage);
  }
}

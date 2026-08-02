import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';

/// Service for eKYC (Electronic Know Your Customer) verification.
/// Handles OTP delivery/verification via REST API and security question operations via GraphQL.
class EkycService {
  /// Predefined security questions for eKYC verification.
  static const List<String> securityQuestions = [
    "What is your pet's name?",
    "What is your mother's maiden name?",
    "What was the name of your first school?",
    "What is your favourite movie?",
    "What city were you born in?",
    "What is your childhood nickname?",
    "What is the name of your best friend?",
  ];

  /// Send an eKYC verification OTP to the user's registered email.
  /// Calls the sosapi REST endpoint with action 'send-ekyc-otp'.
  Future<bool> sendEkycOtp(String email) async {
    try {
      final body = {
        'action': 'send-ekyc-otp',
        'email': email,
      };

      final response = await Amplify.API.post(
        '/sos',
        apiName: 'sosapi',
        body: HttpPayload.json(body),
      ).response;

      safePrint('[EkycService] sendEkycOtp response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.decodeBody());
        safePrint('[EkycService] OTP sent successfully: $data');
        return true;
      }

      safePrint('[EkycService] sendEkycOtp failed: ${response.statusCode}');
      return false;
    } catch (e) {
      safePrint('[EkycService] sendEkycOtp error: $e');
      return false;
    }
  }

  /// Verify the eKYC OTP entered by the user.
  /// Calls the sosapi REST endpoint with action 'verify-ekyc-otp'.
  Future<bool> verifyEkycOtp(String email, String otp) async {
    try {
      final body = {
        'action': 'verify-ekyc-otp',
        'email': email,
        'otp': otp,
      };

      final response = await Amplify.API.post(
        '/sos',
        apiName: 'sosapi',
        body: HttpPayload.json(body),
      ).response;

      safePrint('[EkycService] verifyEkycOtp response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.decodeBody());
        final verified = data['verified'] == true;
        safePrint('[EkycService] OTP verification result: $verified');
        return verified;
      }

      return false;
    } catch (e) {
      safePrint('[EkycService] verifyEkycOtp error: $e');
      return false;
    }
  }

  /// Save the security question and answer to GraphQL (cloud).
  Future<bool> saveSecurityAnswer(String userId, String question, String answer) async {
    try {
      final mutation = '''mutation UpdateUser(\$input: UpdateUserInput!) {
        updateUser(input: \$input) { id securityQuestion securityAnswer }
      }''';

      final request = GraphQLRequest<String>(
        document: mutation,
        variables: {
          'input': {
            'id': userId,
            'securityQuestion': question,
            'securityAnswer': answer,
          }
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      safePrint('[EkycService] saveSecurityAnswer response: ${response.data}');
      return response.data != null;
    } catch (e) {
      safePrint('[EkycService] saveSecurityAnswer error: $e');
      return false;
    }
  }

  /// Mark user as eKYC verified in GraphQL.
  Future<bool> markEkycVerified(String userId) async {
    try {
      final mutation = '''mutation UpdateUser(\$input: UpdateUserInput!) {
        updateUser(input: \$input) { id isEkycVerified }
      }''';

      final request = GraphQLRequest<String>(
        document: mutation,
        variables: {
          'input': {
            'id': userId,
            'isEkycVerified': true,
          }
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      safePrint('[EkycService] markEkycVerified response: ${response.data}');
      return response.data != null;
    } catch (e) {
      safePrint('[EkycService] markEkycVerified error: $e');
      return false;
    }
  }
}

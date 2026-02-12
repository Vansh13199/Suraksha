import 'dart:convert';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

class AuthService {
  Future<AuthUser?> get currentUser async {
    try {
      final result = await Amplify.Auth.getCurrentUser();
      return result;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
    } catch (e) {
      safePrint("Error signing out: $e");
    }
  }

  /// Get the phone number from Cognito user attributes
  Future<String?> _getPhoneFromCognito() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      for (final attr in attributes) {
        if (attr.userAttributeKey == AuthUserAttributeKey.phoneNumber) {
          return attr.value;
        }
      }
    } catch (e) {
      safePrint("[AUTH] Failed to fetch user attributes: $e");
    }
    return null;
  }

  /// Fetch user profile. Strategy:
  /// 1. Try getUser(id: cognitoSub)
  /// 2. If not found, search by phone number using listUsers
  /// 3. If found by phone, migrate record to correct ID
  Future<UserModel?> getUserDetails() async {
    try {
      final authUser = await currentUser;
      if (authUser == null) {
        safePrint("[AUTH] getUserDetails: No authenticated user");
        return null;
      }

      final String cognitoId = authUser.userId;
      safePrint("[AUTH] getUserDetails: cognitoId=$cognitoId");

      // --- Step 1: Try by Cognito ID ---
      final byIdResult = await _getUserById(cognitoId);
      if (byIdResult != null) {
        safePrint("[AUTH] User found by ID ✓");
        return byIdResult;
      }

      // --- Step 2: Try by Phone Number ---
      safePrint("[AUTH] User NOT found by ID. Searching by phone...");
      final phone = await _getPhoneFromCognito();
      if (phone == null) {
        safePrint("[AUTH] Could not get phone from Cognito");
        return null;
      }

      final byPhoneResult = await _getUserByPhone(phone);
      if (byPhoneResult == null) {
        safePrint("[AUTH] No user found by phone either. Truly new user.");
        return null;
      }

      // --- Step 3: Found by phone but wrong ID. Migrate. ---
      safePrint("[AUTH] Found user by phone (old id=${byPhoneResult.uid}). Migrating to id=$cognitoId...");

      // Create new record with correct ID
      await _createUserRecord(cognitoId, byPhoneResult);
      // Delete old record
      await _deleteUserRecord(byPhoneResult.uid);

      safePrint("[AUTH] Migration complete ✓");

      // Return user with correct ID
      return UserModel(
        uid: cognitoId,
        phoneNumber: byPhoneResult.phoneNumber,
        firstName: byPhoneResult.firstName,
        lastName: byPhoneResult.lastName,
        dateOfBirth: byPhoneResult.dateOfBirth,
        gender: byPhoneResult.gender,
        bloodGroup: byPhoneResult.bloodGroup,
        profilePicUrl: byPhoneResult.profilePicUrl,
      );
    } catch (e) {
      safePrint("[AUTH] Error in getUserDetails: $e");
      return null;
    }
  }

  /// Save user profile to DynamoDB. Always uses Cognito Sub as ID.
  Future<void> saveUser(UserModel user) async {
    final authUser = await currentUser;
    if (authUser == null) throw Exception("No authenticated user");

    final String cognitoId = authUser.userId;
    safePrint("[AUTH] saveUser: Using cognitoId=$cognitoId");

    // Check if record already exists
    final existing = await _getUserById(cognitoId);

    final String mutation;
    if (existing == null) {
      mutation = '''mutation CreateUser(\$input: CreateUserInput!) {
        createUser(input: \$input) { id }
      }''';
    } else {
      mutation = '''mutation UpdateUser(\$input: UpdateUserInput!) {
        updateUser(input: \$input) { id }
      }''';
    }

    final request = GraphQLRequest<String>(
      document: mutation,
      variables: {
        'input': {
          'id': cognitoId,
          'phoneNumber': user.phoneNumber,
          'firstName': user.firstName,
          'lastName': user.lastName,
          'dateOfBirth': user.dateOfBirth?.toIso8601String().split('T')[0],
          'gender': user.gender,
          'bloodGroup': user.bloodGroup,
          'profilePicUrl': user.profilePicUrl,
        }
      },
    );

    final response = await Amplify.API.query(request: request).response;
    safePrint('[AUTH] saveUser response: ${response.data}');
    if (response.errors.isNotEmpty) {
      safePrint('[AUTH] saveUser errors: ${response.errors}');
    }
  }

  // --- Private helpers ---

  Future<UserModel?> _getUserById(String id) async {
    try {
      final doc = '''query GetUser(\$id: ID!) {
        getUser(id: \$id) {
          id phoneNumber firstName lastName dateOfBirth gender bloodGroup profilePicUrl
        }
      }''';

      final request = GraphQLRequest<String>(document: doc, variables: {'id': id});
      final response = await Amplify.API.query(request: request).response;

      if (response.data == null) return null;
      final data = jsonDecode(response.data!);
      final userMap = data['getUser'];
      if (userMap == null) return null;

      userMap['uid'] = userMap['id'];
      return UserModel.fromJson(userMap);
    } catch (e) {
      safePrint("[AUTH] _getUserById error: $e");
      return null;
    }
  }

  Future<UserModel?> _getUserByPhone(String phone) async {
    try {
      // Normalize: extract last 10 digits for broad matching
      String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length > 10) {
        digits = digits.substring(digits.length - 10);
      }

      safePrint("[AUTH] Searching by phone exact='$phone' contains='$digits'");

      final doc = '''query ListUsers(\$phone: String!, \$digits: String!) {
        listUsers(filter: {
          or: [
            { phoneNumber: { eq: \$phone } },
            { phoneNumber: { contains: \$digits } }
          ]
        }) {
          items {
            id phoneNumber firstName lastName dateOfBirth gender bloodGroup profilePicUrl
          }
        }
      }''';

      final request = GraphQLRequest<String>(
        document: doc,
        variables: {'phone': phone, 'digits': digits},
      );
      final response = await Amplify.API.query(request: request).response;

      if (response.data == null) return null;
      final data = jsonDecode(response.data!);
      final items = data['listUsers']?['items'] as List?;

      safePrint("[AUTH] listUsers returned ${items?.length ?? 0} results");

      if (items == null || items.isEmpty) return null;

      final userMap = items.first as Map<String, dynamic>;
      userMap['uid'] = userMap['id'];
      return UserModel.fromJson(userMap);
    } catch (e) {
      safePrint("[AUTH] _getUserByPhone error: $e");
      return null;
    }
  }

  Future<void> _createUserRecord(String id, UserModel user) async {
    try {
      final doc = '''mutation CreateUser(\$input: CreateUserInput!) {
        createUser(input: \$input) { id }
      }''';

      final request = GraphQLRequest<String>(
        document: doc,
        variables: {
          'input': {
            'id': id,
            'phoneNumber': user.phoneNumber,
            'firstName': user.firstName,
            'lastName': user.lastName,
            'dateOfBirth': user.dateOfBirth?.toIso8601String().split('T')[0],
            'gender': user.gender,
            'bloodGroup': user.bloodGroup,
            'profilePicUrl': user.profilePicUrl,
          }
        },
      );
      await Amplify.API.query(request: request).response;
    } catch (e) {
      safePrint("[AUTH] _createUserRecord error: $e");
    }
  }

  Future<void> _deleteUserRecord(String id) async {
    try {
      final doc = '''mutation DeleteUser(\$id: ID!) {
        deleteUser(input: { id: \$id }) { id }
      }''';
      final request = GraphQLRequest<String>(document: doc, variables: {'id': id});
      await Amplify.API.query(request: request).response;
    } catch (e) {
      safePrint("[AUTH] _deleteUserRecord error: $e");
    }
  }
}

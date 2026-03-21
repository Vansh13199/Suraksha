import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/user_model.dart';
import '../models/emergency_contact_model.dart';

class AuthService {
  /// Get the currently authenticated user, or null if not signed in.
  Future<AuthUser?> get currentUser async {
    try {
      final result = await Amplify.Auth.getCurrentUser();
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
    } catch (e) {
      safePrint('[AuthService] Error signing out: $e');
    }
  }

  /// Get the phone number from Cognito user attributes.
  Future<String?> _getPhoneFromCognito() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      for (final attr in attributes) {
        if (attr.userAttributeKey == AuthUserAttributeKey.phoneNumber) {
          return attr.value;
        }
      }
    } catch (e) {
      safePrint('[AuthService] Failed to fetch user attributes: $e');
    }
    return null;
  }

  /// Fetch user profile by Cognito Sub (ID).
  Future<UserModel?> getUserDetails() async {
    try {
      final authUser = await currentUser;
      if (authUser == null) {
        safePrint('[AuthService] getUserDetails: No authenticated user');
        return null;
      }

      final String cognitoId = authUser.userId;
      safePrint('[AuthService] getUserDetails: Fetching profile for id=$cognitoId');

      final user = await _getUserById(cognitoId);

      if (user != null) {
        safePrint('[AuthService] Profile found ✓');
      } else {
        safePrint('[AuthService] Profile NOT found. User needs to complete registration.');
      }

      return user;
    } catch (e) {
      safePrint('[AuthService] Error in getUserDetails: $e');
      return null;
    }
  }

  /// Save or update user profile to DynamoDB via GraphQL.
  Future<void> saveUser(UserModel user) async {
    final authUser = await currentUser;
    if (authUser == null) throw Exception('No authenticated user');

    final String cognitoId = authUser.userId;
    safePrint('[AuthService] saveUser: Saving profile for id=$cognitoId');

    // Ensure phoneNumber is never empty
    String phoneNumber = user.phoneNumber;
    if (phoneNumber.isEmpty) {
      safePrint('[AuthService] phoneNumber is empty, fetching from Cognito...');
      phoneNumber = await _getPhoneFromCognito() ?? authUser.username;
      safePrint('[AuthService] Resolved phoneNumber=$phoneNumber');
    }

    // Determine create vs update
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
          'phoneNumber': phoneNumber,
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
    if (response.errors.isNotEmpty) {
      safePrint('[AuthService] saveUser errors: ${response.errors}');
      throw Exception('Failed to save user: ${response.errors.first.message}');
    }
    safePrint('[AuthService] saveUser success');
  }

  // ─── Emergency Contacts ───────────────────────────────────────────

  /// Fetch all emergency contacts for the current user.
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    try {
      final authUser = await currentUser;
      if (authUser == null) return [];

      final String userId = authUser.userId;
      safePrint('[AuthService] Fetching contacts for userId=$userId');

      final doc = '''query ListContacts(\$filter: ModelEmergencyContactFilterInput) {
        listEmergencyContacts(filter: \$filter) {
          items {
            id userId name phoneNumber relationship
          }
        }
      }''';

      final request = GraphQLRequest<String>(
        document: doc,
          variables: {
          'filter': {
            'userId': {'eq': userId}
          }
        },
      );
      final response = await Amplify.API.query(request: request).response;

      safePrint('[AuthService] getEmergencyContacts response: ${response.data}');
      if (response.errors.isNotEmpty) {
        safePrint('[AuthService] getEmergencyContacts errors: ${response.errors}');
        return [];
      }

      if (response.data == null) return [];
      final data = jsonDecode(response.data!);
      final items = data['listEmergencyContacts']?['items'] as List?;

      safePrint('[AuthService] Found ${items?.length ?? 0} contacts');

      if (items == null) return [];

      return items
          .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      safePrint('[AuthService] getEmergencyContacts error: $e');
      return [];
    }
  }

  /// Add an emergency contact (max 5, duplicates skipped).
  Future<bool> addEmergencyContact(String name, String phone, String? relation) async {
    try {
      final authUser = await currentUser;
      if (authUser == null) return false;

      final String userId = authUser.userId;

      // Check current count (limit to 5)
      final currentContacts = await getEmergencyContacts();
      if (currentContacts.length >= 5) {
        safePrint('[AuthService] Contact limit reached.');
        return false;
      }

      // Check for duplicates
      final isDuplicate = currentContacts.any((c) => c.phoneNumber == phone);
      if (isDuplicate) {
        safePrint('[AuthService] Contact already exists.');
        return true;
      }

      final doc = '''mutation CreateContact(\$input: CreateEmergencyContactInput!) {
        createEmergencyContact(input: \$input) { id }
      }''';

      final request = GraphQLRequest<String>(
        document: doc,
          variables: {
          'input': {
            'userId': userId,
            'name': name,
            'phoneNumber': phone,
            'relationship': relation,
          }
        },
      );

      final response = await Amplify.API.mutate(request: request).response;
      if (response.errors.isNotEmpty) {
        safePrint('[AuthService] addContact errors: ${response.errors}');
        return false;
      }
      return true;
    } catch (e) {
      safePrint('[AuthService] addEmergencyContact error: $e');
      return false;
    }
  }

  /// Delete an emergency contact by ID.
  Future<bool> deleteEmergencyContact(String id) async {
    try {
      final doc = '''mutation DeleteContact(\$id: ID!) {
        deleteEmergencyContact(input: { id: \$id }) { id }
      }''';

      final request = GraphQLRequest<String>(
        document: doc,
          variables: {'id': id},
      );

      final response = await Amplify.API.mutate(request: request).response;
      return response.errors.isEmpty;
    } catch (e) {
      safePrint('[AuthService] deleteEmergencyContact error: $e');
      return false;
    }
  }

  // ─── Private Helpers ──────────────────────────────────────────────

  /// Fetch a user by ID from GraphQL.
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
      safePrint('[AuthService] _getUserById error: $e');
      return null;
    }
  }
}

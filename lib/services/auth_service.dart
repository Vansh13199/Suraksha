import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/user_model.dart';
import '../models/emergency_contact_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_notification_service.dart';

class AuthService {
  static const String _userKey = 'suraksha_user_profile';
  static const String _contactsKey = 'suraksha_emergency_contacts';

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

  /// Get the current user's phone number as verified in Cognito attributes.
  Future<String?> getUserPhone() async {
    return _getPhoneFromCognito();
  }

  /// Fetch user profile.
  /// First tries SharedPreferences (Fast/Reliable for Demo/Offline).
  Future<UserModel?> getUserDetails() async {
    try {
      final authUser = await currentUser;
      if (authUser == null) return null;

      // 1. Try Local Cache first
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      
      if (userJson != null) {
        safePrint('[AuthService] Profile found in Local Storage ✓');
        return UserModel.fromJson(jsonDecode(userJson));
      }

      // 2. If no local, try GraphQL (if configured)
      final user = await _getUserFromGraphQL(authUser.userId);
      if (user != null) {
        await saveUser(user); // Cache it locally
      }
      
      return user;
    } catch (e) {
      safePrint('[AuthService] Error in getUserDetails: $e');
      return null;
    }
  }

  /// Save user profile locally and try to sync to GraphQL.
  Future<void> saveUser(UserModel user) async {
    final authUser = await currentUser;
    if (authUser == null) throw Exception('No authenticated user');

    // 1. Save Locally (Always works)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    safePrint('[AuthService] Profile saved to Local Storage');

    // 2. Try to Sync to GraphQL (Silent fail if API not added)
    try {
      await _saveToGraphQL(user, authUser);
    } catch (e) {
      safePrint('[AuthService] GraphQL Sync Skipped/Failed: $e');
    }
  }

  // ─── Emergency Contacts ───────────────────────────────────────────

  /// Fetch all emergency contacts (from Local Storage).
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_contactsKey) ?? [];
      
      final contacts = listJson
          .map((item) => EmergencyContact.fromJson(jsonDecode(item)))
          .toList();
      
      safePrint('[AuthService] Found ${contacts.length} local contacts');
      return contacts;
    } catch (e) {
      safePrint('[AuthService] getEmergencyContacts error: $e');
      return [];
    }
  }

  /// Add an emergency contact locally.
  Future<bool> addEmergencyContact(String name, String phone, String? relation) async {
    try {
      final authUser = await currentUser;
      final userId = authUser?.userId ?? 'local_user';

      final current = await getEmergencyContacts();
      if (current.length >= 5) return false;
      if (current.any((c) => c.phoneNumber == phone)) return true;

      final newContact = EmergencyContact(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        name: name,
        phoneNumber: phone,
        relationship: relation,
      );

      final prefs = await SharedPreferences.getInstance();
      final updatedList = current..add(newContact);
      await prefs.setStringList(
        _contactsKey, 
        updatedList.map((c) => jsonEncode(c.toJson())).toList()
      );

      // 3. Sync to Cloud
      _syncContactToGraphQL(newContact);

      return true;
    } catch (e) {
      safePrint('[AuthService] addEmergencyContact error: $e');
      return false;
    }
  }

  /// Delete an emergency contact locally.
  Future<bool> deleteEmergencyContact(String id) async {
    try {
      final current = await getEmergencyContacts();
      final updatedList = current.where((c) => c.id != id).toList();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _contactsKey, 
        updatedList.map((c) => jsonEncode(c.toJson())).toList()
      );

      // 3. Sync to Cloud
      _deleteContactFromGraphQL(id);

      return true;
    } catch (e) {
      safePrint('[AuthService] deleteEmergencyContact error: $e');
      return false;
    }
  }

  /// Explicitly sync FCM Token to the backend.
  Future<void> syncFcmToken() async {
    try {
      final authUser = await currentUser;
      if (authUser == null) {
        safePrint('[AuthService] FCM Sync skipped: User not logged in.');
        return;
      }

      final fcmToken = await PushNotificationService().getToken();
      if (fcmToken == null) {
        safePrint('[AuthService] FCM Sync skipped: No FCM token available.');
        return;
      }

      final user = await getUserDetails() ?? UserModel(
        uid: authUser.userId,
        phoneNumber: '+918837578715', // Fallback phonenumber for testing
        firstName: 'User',
      );

      safePrint('[AuthService] Syncing FCM Token: $fcmToken');
      await _saveToGraphQL(user, authUser);
      safePrint('[AuthService] FCM Sync Success!');
    } catch (e) {
      safePrint('[AuthService] FCM Sync failed: $e');
    }
  }

  // ─── Internal Implementation (GraphQL) ─────────────────────────────

  Future<UserModel?> _getUserFromGraphQL(String id) async {
    try {
      // Cloud Sync logic

      final doc = '''query GetUser(\$id: ID!) {
        getUser(id: \$id) {
          id phoneNumber firstName lastName dateOfBirth gender bloodGroup profilePicUrl fcmTokens
        }
      }''';
      final request = GraphQLRequest<String>(document: doc, variables: {'id': id});
      final response = await Amplify.API.query(request: request).response;
      if (response.data == null) return null;
      final data = jsonDecode(response.data!);
      final userMap = data['getUser'];
      if (userMap == null) return null;
      userMap['uid'] = userMap['id'];
      // Keep fcmTokens in the raw map or user object? Since we return UserModel, we should either store tokens in UserModel or just let _saveToGraphQL fetch it again.
      // Wait, _getUserFromGraphQL returns UserModel. We need a way to pass fcmTokens to _saveToGraphQL.
      return UserModel.fromJson(userMap)..fcmTokens = List<String>.from(userMap['fcmTokens'] ?? []);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToGraphQL(UserModel user, AuthUser authUser) async {
    // Only attempt if API plugin is enabled
    final cognitoId = authUser.userId;
    final existing = await _getUserFromGraphQL(cognitoId);

    final fcmToken = await PushNotificationService().getToken();
    List<String> tokens = [];
    if (existing != null) {
      tokens = List<String>.from(existing.fcmTokens);
    }
    if (fcmToken != null && !tokens.contains(fcmToken)) {
      tokens.add(fcmToken);
    }

    final mutation = existing == null 
      ? 'mutation CreateUser(\$input: CreateUserInput!) { createUser(input: \$input) { id } }'
      : 'mutation UpdateUser(\$input: UpdateUserInput!) { updateUser(input: \$input) { id } }';

    final request = GraphQLRequest<String>(
      document: mutation,
      variables: {
        'input': {
          'id': cognitoId,
          'phoneNumber': user.phoneNumber.isEmpty ? authUser.username : user.phoneNumber,
          'firstName': user.firstName,
          'lastName': user.lastName,
          'dateOfBirth': user.dateOfBirth?.toIso8601String().split('T')[0],
          'gender': user.gender,
          'bloodGroup': user.bloodGroup,
          'profilePicUrl': user.profilePicUrl,
          'fcmTokens': tokens,
        }
      },
    );
    await Amplify.API.mutate(request: request).response;
  }

  Future<void> _syncContactToGraphQL(EmergencyContact contact) async {
    try {
      final doc = '''mutation CreateContact(\$input: CreateEmergencyContactInput!) {
        createEmergencyContact(input: \$input) { id }
      }''';
      final request = GraphQLRequest<String>(
        document: doc,
        variables: {
          'input': {
            'id': contact.id,
            'name': contact.name,
            'phoneNumber': contact.phoneNumber,
            'relationship': contact.relationship,
            'userId': contact.userId,
          }
        },
      );
      await Amplify.API.mutate(request: request).response;
      safePrint('[AuthService] Contact synced to Cloud ✓');
    } catch (e) {
      safePrint('[AuthService] Contact sync failed: $e');
    }
  }

  Future<void> _deleteContactFromGraphQL(String id) async {
    try {
      final doc = '''mutation DeleteContact(\$input: DeleteEmergencyContactInput!) {
        deleteEmergencyContact(input: \$input) { id }
      }''';
      final request = GraphQLRequest<String>(
        document: doc,
        variables: {
          'input': { 'id': id }
        },
      );
      await Amplify.API.mutate(request: request).response;
      safePrint('[AuthService] Contact deleted from Cloud ✓');
    } catch (e) {
      safePrint('[AuthService] Contact delete sync failed: $e');
    }
  }
}

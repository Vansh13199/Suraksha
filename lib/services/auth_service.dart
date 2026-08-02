import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/user_model.dart';
import '../models/emergency_contact_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
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

  /// Sign out the current user and clear local cache.
  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_contactsKey);
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

  /// Get the email from Cognito user attributes.
  Future<String?> _getEmailFromCognito() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      for (final attr in attributes) {
        if (attr.userAttributeKey == AuthUserAttributeKey.email) {
          return attr.value;
        }
      }
    } catch (e) {
      safePrint('[AuthService] Failed to fetch user email attribute: $e');
    }
    return null;
  }

  /// Get the current user's phone number as verified in Cognito attributes.
  Future<String?> getUserPhone() async {
    return _getPhoneFromCognito();
  }

  /// Get the current user's email as verified in Cognito attributes.
  Future<String?> getUserEmail() async {
    return _getEmailFromCognito();
  }

  /// Fetch user profile.
  /// First tries SharedPreferences (Fast/Reliable for Demo/Offline).
  Future<UserModel?> getUserDetails() async {
    try {
      final authUser = await currentUser;
      if (authUser == null) return null;

      UserModel? user;
      
      // 1. Try GraphQL first to get latest data
      try {
        user = await _getUserFromGraphQL(authUser.userId);
        if (user != null) {
          // Update local cache with fresh data
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_userKey, jsonEncode(user.toJson()));
          safePrint('[AuthService] Fetched fresh profile from cloud and updated cache ✓');
        }
      } catch (e) {
        safePrint('[AuthService] Failed to fetch from cloud: $e');
      }

      // 2. If cloud fetch failed or returned null, fallback to Local Cache
      if (user == null) {
        final prefs = await SharedPreferences.getInstance();
        final userJson = prefs.getString(_userKey);
        
        if (userJson != null) {
          final cachedUser = UserModel.fromJson(jsonDecode(userJson));
          
          // CRITICAL: Ensure the cached data belongs to the currently logged-in user!
          if (cachedUser.uid == authUser.userId) {
            safePrint('[AuthService] Profile loaded from Local Storage fallback ✓');
            user = cachedUser;
          } else {
            safePrint('[AuthService] Local cache belongs to a different user. Discarding.');
            await prefs.remove(_userKey);
            user = null;
          }
        }
      }

      // Auto-fix if email is missing or accidentally set to the Cognito UUID
      if (user != null && (user.email.isEmpty || user.email.contains('-'))) {
        final realEmail = await getUserEmail();
        if (realEmail != null && realEmail.isNotEmpty) {
          user = UserModel(
            uid: user.uid,
            email: realEmail,
            phoneNumber: user.phoneNumber,
            firstName: user.firstName,
            lastName: user.lastName,
            dateOfBirth: user.dateOfBirth,
            gender: user.gender,
            bloodGroup: user.bloodGroup,
            profilePicUrl: user.profilePicUrl,
          )..fcmTokens = user.fcmTokens;
          
          await saveUser(user); // Cache it and sync back to cloud
        }
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

  // ─── Profile Picture S3 Integration ──────────────────────────────
  
  /// Upload a profile picture to S3 and save the key to the user profile
  Future<bool> uploadProfilePicture(String filePath) async {
    try {
      final authUser = await currentUser;
      if (authUser == null) return false;

      final key = 'profile_pictures/${authUser.userId}.jpg';
      final file = AWSFile.fromPath(filePath);
      
      safePrint('[AuthService] Uploading profile picture to S3...');
      await Amplify.Storage.uploadFile(
        localFile: file,
        key: key,
      ).result;
      
      // Update User Model
      final user = await getUserDetails();
      if (user != null) {
        final updatedUser = UserModel(
          uid: user.uid,
          email: user.email,
          phoneNumber: user.phoneNumber,
          firstName: user.firstName,
          lastName: user.lastName,
          dateOfBirth: user.dateOfBirth,
          gender: user.gender,
          bloodGroup: user.bloodGroup,
          profilePicUrl: key, // Store the S3 Key, not the full URL
        )..fcmTokens = user.fcmTokens;
        
        await saveUser(updatedUser);
      }
      return true;
    } catch (e) {
      safePrint('[AuthService] Error uploading profile picture: $e');
      return false;
    }
  }

  /// Remove the profile picture from S3 and update the user profile
  Future<bool> removeProfilePicture() async {
    try {
      final user = await getUserDetails();
      if (user == null || user.profilePicUrl == null || user.profilePicUrl!.isEmpty) return false;

      safePrint('[AuthService] Removing profile picture from S3...');
      await Amplify.Storage.remove(
        key: user.profilePicUrl!,
      ).result;
      
      // Update User Model
      final updatedUser = UserModel(
        uid: user.uid,
        email: user.email,
        phoneNumber: user.phoneNumber,
        firstName: user.firstName,
        lastName: user.lastName,
        dateOfBirth: user.dateOfBirth,
        gender: user.gender,
        bloodGroup: user.bloodGroup,
        profilePicUrl: null, // Clear the URL
      )..fcmTokens = user.fcmTokens;
      
      await saveUser(updatedUser);
      return true;
    } catch (e) {
      safePrint('[AuthService] Error removing profile picture: $e');
      return false;
    }
  }

  /// Fetch a temporary signed URL for the profile picture
  Future<String?> getProfilePictureUrl(String key) async {
    try {
      final result = await Amplify.Storage.getUrl(
        key: key,
        options: StorageGetUrlOptions(
          pluginOptions: const S3GetUrlPluginOptions(
            expiresIn: Duration(hours: 1),
          ),
        ),
      ).result;
      return result.url.toString();
    } catch (e) {
      safePrint('[AuthService] Error getting signed URL: $e');
      return null;
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

      final user = await getUserDetails();
      if (user == null) {
        safePrint('[AuthService] FCM Sync skipped: User profile not created yet.');
        return;
      }

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
          id email phoneNumber firstName lastName dateOfBirth gender bloodGroup profilePicUrl isEkycVerified securityQuestion securityAnswer fcmTokens
        }
      }''';
      final request = GraphQLRequest<String>(document: doc, variables: {'id': id});
      final response = await Amplify.API.query(request: request).response;
      if (response.data == null) return null;
      final data = jsonDecode(response.data!);
      final userMap = data['getUser'];
      if (userMap == null) return null;
      userMap['uid'] = userMap['id'];
      userMap['email'] = userMap['email'] ?? '';
      // Keep fcmTokens in the raw map or user object? Since we return UserModel, we should either store tokens in UserModel or just let _saveToGraphQL fetch it again.
      // Wait, _getUserFromGraphQL returns UserModel. We need a way to pass fcmTokens to _saveToGraphQL.
      return UserModel.fromJson(userMap)..fcmTokens = List<String>.from(userMap['fcmTokens'] ?? []);
    } catch (e, stack) {
      safePrint('[AuthService] _getUserFromGraphQL Error: $e\n$stack');
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
          'email': user.email.isNotEmpty ? user.email : (await _getEmailFromCognito() ?? ''),
          'phoneNumber': user.phoneNumber,
          'firstName': user.firstName,
          'lastName': user.lastName,
          'dateOfBirth': user.dateOfBirth?.toIso8601String().split('T')[0],
          'gender': user.gender,
          'bloodGroup': user.bloodGroup,
          'profilePicUrl': user.profilePicUrl,
          'isEkycVerified': user.isEkycVerified,
          'securityQuestion': user.securityQuestion,
          'securityAnswer': user.securityAnswer,
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

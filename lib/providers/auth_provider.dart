import 'dart:async';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart' hide AuthProvider;
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart' hide AuthProvider;
import '../services/auth_service.dart';
import '../services/ekyc_service.dart';
import '../models/user_model.dart';
import 'dart:math';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final EkycService _ekycService = EkycService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _tempEmail;
  bool _isSignedIn = false;
  String? _errorMessage;
  bool _isAwaitingOtp = false;
  final Completer<void> _initCompleter = Completer<void>();

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get tempEmail => _tempEmail;
  bool get isSignedIn => _isSignedIn;
  String? get errorMessage => _errorMessage;
  bool get isAwaitingOtp => _isAwaitingOtp;
  bool get isEkycVerified => _currentUser?.isEkycVerified ?? false;

  /// Wait for the initial auth check + profile fetch to finish.
  Future<void> waitForInit() => _initCompleter.future;

  AuthProvider() {
    _init();
  }

  void _init() {
    // Listen to Amplify Auth Hub events
    Amplify.Hub.listen(HubChannel.Auth, (AuthHubEvent event) {
      if (event.type == AuthHubEventType.signedIn) {
        safePrint('[AuthProvider] Signed In');
        _isSignedIn = true;
        _isAwaitingOtp = false;
        _fetchUserDetails();
      } else if (event.type == AuthHubEventType.signedOut) {
        safePrint('[AuthProvider] Signed Out');
        _isSignedIn = false;
        _currentUser = null;
        notifyListeners();
      } else if (event.type == AuthHubEventType.sessionExpired) {
        safePrint('[AuthProvider] Session Expired');
        _isSignedIn = false;
        _currentUser = null;
        notifyListeners();
      }
    });

    // Check if already signed in
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      _isSignedIn = session.isSignedIn;
      safePrint('[AuthProvider] _checkAuthStatus: isSignedIn=$_isSignedIn');
      if (_isSignedIn) {
        await _fetchUserDetails();
      }
      notifyListeners();
    } catch (e) {
      safePrint('[AuthProvider] Error checking auth status: $e');
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  /// Sign up with email (passwordless — just creates user).
  Future<bool> signUp({required String email}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final randomPassword = _generateRandomPassword();

      final result = await Amplify.Auth.signUp(
        username: email,
        password: randomPassword,
        options: SignUpOptions(
          userAttributes: {
            AuthUserAttributeKey.email: email,
          },
        ),
      );

      safePrint('[AuthProvider] SignUp result: ${result.nextStep.signUpStep}');
      _tempEmail = email;
      _isLoading = false;
      notifyListeners();
      return result.isSignUpComplete || result.nextStep.signUpStep == AuthSignUpStep.confirmSignUp;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      safePrint('[AuthProvider] SignUp Error: ${e.message}');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Start passwordless sign-in with email.
  /// Triggers Custom Auth flow and sends OTP via Lambda (SES).
  /// Automatically signs up new users if they don't exist.
  Future<bool> sendOtp(String email) async {
    _isLoading = true;
    _errorMessage = null;
    _tempEmail = email;
    notifyListeners();

    try {
      // Force sign-out to clear any stale sessions
      try {
        await Amplify.Auth.signOut();
      } catch (_) {}

      final result = await Amplify.Auth.signIn(
        username: email,
        password: 'SurakshaPassword@123',
        options: SignInOptions(
          pluginOptions: const CognitoSignInPluginOptions(
            authFlowType: AuthenticationFlowType.customAuthWithSrp,
          ),
        ),
      );

      safePrint('[AuthProvider] SignIn result: $result');
      safePrint('[AuthProvider] Step: ${result.nextStep.signInStep}');
      safePrint('[AuthProvider] IsSignedIn: ${result.isSignedIn}');

      if (result.nextStep.signInStep == AuthSignInStep.confirmSignInWithCustomChallenge) {
        _isAwaitingOtp = true;

        final debugOtp = result.nextStep.additionalInfo['debugOtp'];
        if (debugOtp != null) {
          safePrint('────────────────────────────────────');
          safePrint('[DEBUG] OTP RECEIVED: $debugOtp');
          safePrint('────────────────────────────────────');
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }

      if (result.isSignedIn) {
        _isSignedIn = true;
        _isAwaitingOtp = false;
        await _fetchUserDetails();
      }

      _isLoading = false;
      notifyListeners();
      return result.isSignedIn;
    } on NotAuthorizedServiceException catch (e) {
      safePrint('[AuthProvider] User not authorized, attempting sign up: ${e.message}');
      return await _handleNewUserSignUp(email);
    } on UserNotFoundException catch (e) {
      safePrint('[AuthProvider] User not found, attempting sign up: ${e.message}');
      return await _handleNewUserSignUp(email);
    } on AuthException catch (e) {
      _errorMessage = 'Auth Error: ${e.message}\nRecovery: ${e.recoverySuggestion}\nInner: ${e.underlyingException}';
      safePrint('[AuthProvider] SendOTP AuthException: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Unexpected Error: $e';
      safePrint('[AuthProvider] SendOTP Unexpected Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Handle new user registration and then initiate OTP.
  Future<bool> _handleNewUserSignUp(String email) async {
    try {
      safePrint('[AuthProvider] Attempting to create user via API: $email');

      final body = {
        'action': 'signup',
        'email': email,
        'password': 'SurakshaPassword@123',
      };

      final response = await Amplify.API.post(
        '/sos',
        apiName: 'sosapi',
        body: HttpPayload.json(body),
      ).response;

      safePrint('[AuthProvider] Signup API Response: ${response.statusCode} ${response.body}');

      if (response.statusCode != 200) {
        _errorMessage = 'Failed to create account (API ${response.statusCode}).';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Now initiate sign-in for OTP (user is CONFIRMED by lambda)
      final result = await Amplify.Auth.signIn(
        username: email,
        password: 'SurakshaPassword@123',
        options: SignInOptions(
          pluginOptions: const CognitoSignInPluginOptions(
            authFlowType: AuthenticationFlowType.customAuthWithSrp,
          ),
        ),
      );

      safePrint('[AuthProvider] SignIn after signUp: ${result.nextStep.signInStep}');

      if (result.nextStep.signInStep == AuthSignInStep.confirmSignInWithCustomChallenge) {
        _isAwaitingOtp = true;

        final debugOtp = result.nextStep.additionalInfo['debugOtp'];
        if (debugOtp != null) {
          safePrint('────────────────────────────────────');
          safePrint('[DEBUG] OTP RECEIVED (New User): $debugOtp');
          safePrint('────────────────────────────────────');
        }

        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return result.isSignedIn;
    } on ApiException catch (e) {
      _errorMessage = 'SignUp API Error: ${e.message}';
      safePrint('[AuthProvider] SignUp API Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _errorMessage = 'SignUp Error: ${e.message}\nRecovery: ${e.recoverySuggestion}';
      safePrint('[AuthProvider] Auto SignUp Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Unexpected Error: $e';
      safePrint('[AuthProvider] Unexpected SignUp Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify the OTP code entered by user.
  Future<bool> verifyOtp(String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await Amplify.Auth.confirmSignIn(
        confirmationValue: otp.trim(),
      );

      safePrint('[AuthProvider] VerifyOTP result: ${result.isSignedIn}');

      if (result.isSignedIn) {
        _isSignedIn = true;
        _isAwaitingOtp = false;
        await _fetchUserDetails();
        _isLoading = false;
        notifyListeners();
        return true;
      }

      if (result.nextStep.signInStep == AuthSignInStep.confirmSignInWithCustomChallenge) {
        _errorMessage = 'Incorrect OTP. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      safePrint('[AuthProvider] VerifyOTP Error: ${e.message}');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _fetchUserDetails() async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentUser = await _authService.getUserDetails();
      safePrint('[AuthProvider] _fetchUserDetails: currentUser=${_currentUser?.firstName ?? "NULL"}');
      if (_currentUser != null) {
        _authService.syncFcmToken();
      }
    } catch (e) {
      safePrint('[AuthProvider] Error fetching user details: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Reload user details from the database (e.g. after profile updates).
  Future<void> refreshUser() async {
    try {
      final updatedUser = await _authService.getUserDetails();
      if (updatedUser != null) {
        _currentUser = updatedUser;
        _authService.syncFcmToken();
        notifyListeners();
      }
    } catch (e) {
      safePrint('[AuthProvider] Error refreshing user details: $e');
    }
  }

  Future<void> updateUserDetails(UserModel updatedUser) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.saveUser(updatedUser);
      _currentUser = updatedUser;
    } catch (e) {
      safePrint('[AuthProvider] Error: $e');
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _isSignedIn = false;
    _isAwaitingOtp = false;
    _currentUser = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void cancelOtpFlow() {
    _isAwaitingOtp = false;
    _tempEmail = null;
    notifyListeners();
  }

  /// Save the security question and answer for eKYC.
  Future<bool> saveSecurityAnswer(String question, String answer) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_currentUser == null) {
        try {
          final authUser = await Amplify.Auth.getCurrentUser();
          final email = _tempEmail ?? await _authService.getUserEmail() ?? '';
          _currentUser = UserModel(
            uid: authUser.userId,
            email: email,
            phoneNumber: '',
          );
        } catch (e) {
          _errorMessage = 'Could not retrieve user session. Please re-login.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      _currentUser = UserModel(
        uid: _currentUser!.uid,
        email: _currentUser!.email,
        phoneNumber: _currentUser!.phoneNumber,
        firstName: _currentUser!.firstName,
        lastName: _currentUser!.lastName,
        dateOfBirth: _currentUser!.dateOfBirth,
        gender: _currentUser!.gender,
        bloodGroup: _currentUser!.bloodGroup,
        profilePicUrl: _currentUser!.profilePicUrl,
        isEkycVerified: _currentUser!.isEkycVerified,
        securityQuestion: question,
        securityAnswer: answer,
      )..fcmTokens = _currentUser!.fcmTokens;

      // Always save locally + trigger standard GraphQL sync
      await _authService.saveUser(_currentUser!);

      // Best-effort attempt dedicated eKYC GraphQL update
      try {
        await _ekycService.saveSecurityAnswer(_currentUser!.uid, question, answer);
      } catch (e) {
        safePrint('[AuthProvider] Cloud sync for security QA skipped/failed: $e');
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error saving security answer: $e';
      safePrint('[AuthProvider] saveSecurityAnswer error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Complete eKYC verification — marks user as verified.
  Future<bool> completeEkyc() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_currentUser == null) {
        try {
          final authUser = await Amplify.Auth.getCurrentUser();
          final email = _tempEmail ?? await _authService.getUserEmail() ?? '';
          _currentUser = UserModel(
            uid: authUser.userId,
            email: email,
            phoneNumber: '',
          );
        } catch (e) {
          _errorMessage = 'Could not retrieve user session. Please re-login.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      _currentUser = UserModel(
        uid: _currentUser!.uid,
        email: _currentUser!.email,
        phoneNumber: _currentUser!.phoneNumber,
        firstName: _currentUser!.firstName,
        lastName: _currentUser!.lastName,
        dateOfBirth: _currentUser!.dateOfBirth,
        gender: _currentUser!.gender,
        bloodGroup: _currentUser!.bloodGroup,
        profilePicUrl: _currentUser!.profilePicUrl,
        isEkycVerified: true,
        securityQuestion: _currentUser!.securityQuestion,
        securityAnswer: _currentUser!.securityAnswer,
      )..fcmTokens = _currentUser!.fcmTokens;

      // Always save locally + trigger standard GraphQL sync
      await _authService.saveUser(_currentUser!);
      safePrint('[AuthProvider] eKYC completed successfully locally ✓');

      // Best-effort attempt dedicated eKYC GraphQL update
      try {
        await _ekycService.markEkycVerified(_currentUser!.uid);
      } catch (e) {
        safePrint('[AuthProvider] Cloud sync for markEkycVerified skipped/failed: $e');
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'eKYC Error: $e';
      safePrint('[AuthProvider] completeEkyc error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Generate a strong secure password for Cognito (user never sees this).
  String _generateRandomPassword() {
    final random = Random.secure();
    const uppers = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowers = 'abcdefghijklmnopqrstuvwxyz';
    const digits = '0123456789';
    const symbols = '!@#\$%^&*';

    String password = '';
    password += uppers[random.nextInt(uppers.length)];
    password += lowers[random.nextInt(lowers.length)];
    password += digits[random.nextInt(digits.length)];
    password += symbols[random.nextInt(symbols.length)];

    const allChars = '$uppers$lowers$digits$symbols';
    for (int i = 0; i < 12; i++) {
      password += allChars[random.nextInt(allChars.length)];
    }

    final charList = password.split('')..shuffle(random);
    return charList.join();
  }
}

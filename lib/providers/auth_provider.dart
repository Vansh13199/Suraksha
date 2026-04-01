import 'dart:async';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart' hide AuthProvider;
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart' hide AuthProvider;
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'dart:math';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _tempPhoneNumber;
  bool _isSignedIn = false;
  String? _errorMessage;
  bool _isAwaitingOtp = false;
  final Completer<void> _initCompleter = Completer<void>();

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get tempPhoneNumber => _tempPhoneNumber;
  bool get isSignedIn => _isSignedIn;
  String? get errorMessage => _errorMessage;
  bool get isAwaitingOtp => _isAwaitingOtp;

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

  /// Sign up with phone number (passwordless — just creates user).
  Future<bool> signUp({required String phoneNumber}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final randomPassword = _generateRandomPassword();

      final result = await Amplify.Auth.signUp(
        username: phoneNumber,
        password: randomPassword,
        options: SignUpOptions(
          userAttributes: {
            AuthUserAttributeKey.phoneNumber: phoneNumber,
          },
        ),
      );

      safePrint('[AuthProvider] SignUp result: ${result.nextStep.signUpStep}');
      _tempPhoneNumber = phoneNumber;
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

  /// Start passwordless sign-in with phone number.
  /// Triggers Custom Auth flow and sends OTP via Lambda.
  /// Automatically signs up new users if they don't exist.
  Future<bool> sendOtp(String phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    _tempPhoneNumber = phoneNumber;
    notifyListeners();

    try {
      // Force sign-out to clear any stale sessions
      try {
        await Amplify.Auth.signOut();
      } catch (_) {}

      final result = await Amplify.Auth.signIn(
        username: phoneNumber,
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
      return await _handleNewUserSignUp(phoneNumber);
    } on UserNotFoundException catch (e) {
      safePrint('[AuthProvider] User not found, attempting sign up: ${e.message}');
      return await _handleNewUserSignUp(phoneNumber);
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
  Future<bool> _handleNewUserSignUp(String phoneNumber) async {
    try {
      safePrint('[AuthProvider] Attempting to create user via API: $phoneNumber');

      final body = {
        'action': 'signup',
        'phoneNumber': phoneNumber,
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
        username: phoneNumber,
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
    } catch (e) {
      safePrint('[AuthProvider] Error fetching user details: $e');
    }
    _isLoading = false;
    notifyListeners();
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
    _tempPhoneNumber = null;
    notifyListeners();
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

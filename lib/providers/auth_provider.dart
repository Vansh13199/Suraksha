import 'dart:async';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

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
  /// SplashScreen calls this before making routing decisions.
  Future<void> waitForInit() => _initCompleter.future;

  AuthProvider() {
    _init();
  }

  void _init() {
    // Listen to Auth Events (Login/Logout)
    Amplify.Hub.listen(HubChannel.Auth, (AuthHubEvent event) {
      if (event.type == AuthHubEventType.signedIn) {
        safePrint('AuthProvider: Signed In');
        _isSignedIn = true;
        _isAwaitingOtp = false;
        _fetchUserDetails();
      } else if (event.type == AuthHubEventType.signedOut) {
        safePrint('AuthProvider: Signed Out');
        _isSignedIn = false;
        _currentUser = null;
        notifyListeners();
      } else if (event.type == AuthHubEventType.sessionExpired) {
        safePrint('AuthProvider: Session Expired');
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
      safePrint('[AUTH] _checkAuthStatus: isSignedIn=$_isSignedIn');
      if (_isSignedIn) {
        await _fetchUserDetails();
      }
      notifyListeners();
    } catch (e) {
      safePrint('[AUTH] Error checking auth status: $e');
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  /// Sign Up with Phone Number (passwordless - just creates user)
  Future<bool> signUp({required String phoneNumber}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // For passwordless, we still need a password for Cognito user pool
      // Using a random secure password that user never needs to know
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

      safePrint('SignUp result: ${result.nextStep.signUpStep}');
      _tempPhoneNumber = phoneNumber;
      _isLoading = false;
      notifyListeners();
      return result.isSignUpComplete || result.nextStep.signUpStep == AuthSignUpStep.confirmSignUp;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      safePrint('SignUp Error: ${e.message}');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Start passwordless sign-in with phone number
  /// This triggers the Custom Auth flow and sends OTP via Lambda
  /// Automatically signs up new users if they don't exist
  Future<bool> sendOtp(String phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    _tempPhoneNumber = phoneNumber;
    notifyListeners();

    try {
      // Force sign-out to clear any stale sessions
      try {
        await Amplify.Auth.signOut();
      } catch (_) {
        // Ignore if already signed out
      }
      
      final result = await Amplify.Auth.signIn(
        username: phoneNumber,
        options: SignInOptions(
          pluginOptions: const CognitoSignInPluginOptions(
            authFlowType: AuthenticationFlowType.customAuthWithoutSrp,
          ),
        ),
      );

      safePrint('SignIn result: ${result.nextStep.signInStep}');

      // Check if we need to confirm with custom challenge (OTP)
      if (result.nextStep.signInStep == AuthSignInStep.confirmSignInWithCustomChallenge) {
        _isAwaitingOtp = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Already signed in (shouldn't happen for OTP flow)
      if (result.isSignedIn) {
        _isSignedIn = true;
        _isAwaitingOtp = false;
        await _fetchUserDetails();
      }

      _isLoading = false;
      notifyListeners();
      return result.isSignedIn;
    } on NotAuthorizedServiceException catch (e) {
      // User not found or not confirmed - try to sign up first
      safePrint('User not found or not authorized, attempting sign up: ${e.message}');
      return await _handleNewUserSignUp(phoneNumber);
    } on UserNotFoundException catch (e) {
      // User doesn't exist - sign them up
      safePrint('User not found, attempting sign up: ${e.message}');
      return await _handleNewUserSignUp(phoneNumber);
    } on AuthException catch (e) {
      _errorMessage = e.message;
      safePrint('SendOTP Error: ${e.message}');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Helper method to handle new user registration and then initiate OTP
  Future<bool> _handleNewUserSignUp(String phoneNumber) async {
    try {
      // First, sign up the user
      final signUpSuccess = await signUp(phoneNumber: phoneNumber);
      
      if (!signUpSuccess) {
        _errorMessage = 'Failed to create account. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Now initiate sign-in for OTP
      final result = await Amplify.Auth.signIn(
        username: phoneNumber,
        options: SignInOptions(
          pluginOptions: CognitoSignInPluginOptions(
            authFlowType: AuthenticationFlowType.customAuthWithoutSrp,
          ),
        ),
      );

      safePrint('SignIn after signUp result: ${result.nextStep.signInStep}');

      if (result.nextStep.signInStep == AuthSignInStep.confirmSignInWithCustomChallenge) {
        _isAwaitingOtp = true;
        _isLoading = false;
        _errorMessage = null; // Clear any error from the auto-signup
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return result.isSignedIn;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      safePrint('Auto SignUp Error: ${e.message}');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify the OTP code entered by user
  Future<bool> verifyOtp(String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await Amplify.Auth.confirmSignIn(
        confirmationValue: otp,
      );

      safePrint('VerifyOTP result: ${result.isSignedIn}');

      if (result.isSignedIn) {
        _isSignedIn = true;
        _isAwaitingOtp = false;
        await _fetchUserDetails();
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Check if another challenge is needed
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
      safePrint('VerifyOTP Error: ${e.message}');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _fetchUserDetails() async {
    _isLoading = true;
    notifyListeners();
    _currentUser = await _authService.getUserDetails();
    safePrint('[AUTH] _fetchUserDetails: currentUser=${_currentUser?.firstName ?? "NULL"}');
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
      safePrint("Error: $e");
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

  /// Generate a random secure password for Cognito (user never sees this)
  String _generateRandomPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(16, (index) => chars[(random + index * 7) % chars.length]).join();
  }
}

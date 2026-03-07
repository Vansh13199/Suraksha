import 'dart:convert';
import 'dart:typed_data'; 
import 'dart:async'; // Required for Completer
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart' hide AuthProvider; // Avoid conflict with class name
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart' hide AuthProvider;
import 'package:amplify_api/amplify_api.dart'; // Required for RestOptions, ApiException
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

      safePrint('[DEBUG] SignIn result: $result');
      safePrint('[DEBUG] Step: ${result.nextStep.signInStep}');
      safePrint('[DEBUG] IsSignedIn: ${result.isSignedIn}');

      // Check if we need to confirm with custom challenge (OTP)
      if (result.nextStep.signInStep == AuthSignInStep.confirmSignInWithCustomChallenge) {
        _isAwaitingOtp = true;
        
        // Check for Debug OTP
        final debugOtp = result.nextStep.additionalInfo?['debugOtp'];
        if (debugOtp != null) {
          safePrint('----------------------------------------');
          safePrint('[DEBUG] OTP RECEIVED: $debugOtp');
          safePrint('----------------------------------------');
        }
        
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
      // FORCE FULL ERROR TO UI for debugging
      _errorMessage = "Auth Error: ${e.message}\nRecovery: ${e.recoverySuggestion}\nInner: ${e.underlyingException}";
      safePrint('SendOTP AuthException: $e');
      safePrint('Recovery Suggestion: ${e.recoverySuggestion}');
      safePrint('Underlying Exception: ${e.underlyingException}');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = "Unexpected Error: $e";
      safePrint('SendOTP Unexpected Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Helper method to handle new user registration and then initiate OTP
  Future<bool> _handleNewUserSignUp(String phoneNumber) async {
    try {
      safePrint('[SIGNUP] Attempting to create user via API: $phoneNumber');
      
      // Call the API to create user (auto-confirms via Lambda)
      // Call the API to create user (auto-confirms via Lambda)
      final body = {
          'action': 'signup',
          'phoneNumber': phoneNumber,
          'password': _generateRandomPassword(), 
      };
      
      final response = await Amplify.API.post(
        '/sos', 
        apiName: 'sosapi',
        body: HttpPayload.json(body),
      ).response;

      safePrint('[SIGNUP] API Response: ${response.statusCode} ${response.body}');

      if (response.statusCode != 200) {
        _errorMessage = 'Failed to create account (API ${response.statusCode}).';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Now initiate sign-in for OTP
      // (User is now CONFIRMED by the lambda)
      final result = await Amplify.Auth.signIn(
        username: phoneNumber,
        options: SignInOptions(
          pluginOptions: const CognitoSignInPluginOptions(
            authFlowType: AuthenticationFlowType.customAuthWithoutSrp,
          ),
        ),
      );

      safePrint('SignIn after signUp result: ${result.nextStep.signInStep}');

      if (result.nextStep.signInStep == AuthSignInStep.confirmSignInWithCustomChallenge) {
        _isAwaitingOtp = true;
        
        // Check for Debug OTP
        final debugOtp = result.nextStep.additionalInfo?['debugOtp'];
        if (debugOtp != null) {
          safePrint('----------------------------------------');
          safePrint('[DEBUG] OTP RECEIVED (New User): $debugOtp');
          safePrint('----------------------------------------');
        }

        _isLoading = false;
        _errorMessage = null; // Clear any error from the auto-signup
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return result.isSignedIn;
    } on ApiException catch (e) {
       _errorMessage = "SignUp API Error: ${e.message}";
       safePrint('SignUp API Error: $e');
       _isLoading = false;
       notifyListeners();
       return false;
    } on AuthException catch (e) {
      _errorMessage = "SignUp Error: ${e.message}\nRecovery: ${e.recoverySuggestion}";
      safePrint('Auto SignUp Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = "Unexpected Error: $e";
      safePrint('Unexpected SignUp Error: $e');
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
    try {
      _currentUser = await _authService.getUserDetails();
      safePrint('[AUTH] _fetchUserDetails: currentUser=${_currentUser?.firstName ?? "NULL"}');
    } catch (e) {
      safePrint('[AUTH] Error fetching user details: $e');
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
      safePrint("Error: $e");
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

  /// Generate a strong secure password for Cognito (user never sees this)
  String _generateRandomPassword() {
    final random = Random.secure();
    // Ensure at least one of each required character type
    const uppers = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowers = 'abcdefghijklmnopqrstuvwxyz';
    const digits = '0123456789';
    const symbols = '!@#\$%^&*';
    
    String password = '';
    password += uppers[random.nextInt(uppers.length)];
    password += lowers[random.nextInt(lowers.length)];
    password += digits[random.nextInt(digits.length)];
    password += symbols[random.nextInt(symbols.length)];
    
    // Fill the rest (12 chars) with mixed
    const allChars = '$uppers$lowers$digits$symbols';
    for (int i = 0; i < 12; i++) {
        password += allChars[random.nextInt(allChars.length)];
    }
    
    // Shuffle to randomize positions
    final charList = password.split('')..shuffle(random);
    return charList.join();
  }
}

# Suraksha+ - Agent Documentation

## Project Overview

Suraksha+ is a **production-grade personal safety application** built with Flutter. The app is designed to provide emergency SOS functionality by integrating with ESP32-based wearable hardware devices via Bluetooth Low Energy (BLE). It features passwordless OTP authentication, real-time location tracking, and intelligent SOS routing logic that determines the optimal communication path during emergencies.

### Key Capabilities
- **Emergency SOS Activation**: Trigger SOS via app button or ESP32 hardware device
- **Passwordless Authentication**: Phone number-based OTP login using AWS Cognito
- **Real-time Location Tracking**: GPS tracking with privacy controls (only active during SOS)
- **BLE Hardware Integration**: Connects to ESP32 devices for hardware-triggered SOS
- **Intelligent SOS Routing**: Decision engine that routes SOS through phone SIM or ESP eSIM based on connectivity

---

## Technology Stack

### Core Framework
| Component | Technology |
|-----------|------------|
| Framework | Flutter 3.2+ |
| Language | Dart |
| State Management | Provider |
| Backend | AWS Amplify (Auth + API) |
| Maps | Google Maps Flutter |
| BLE Communication | Flutter Blue Plus |

### Backend Services (AWS)
- **AWS Cognito**: User authentication with custom OTP flow
- **AWS AppSync**: GraphQL API for user data
- **AWS Lambda**: OTP generation and verification triggers
- ~~Firebase~~: Removed - using AWS Amplify only

### Key Dependencies
```yaml
# State Management
provider: ^6.1.1

# AWS Amplify
amplify_flutter: ^1.6.0
amplify_auth_cognito: ^1.6.0
amplify_api: ^1.6.0

# Maps & Location
google_maps_flutter: ^2.5.0
geolocator: ^10.1.0
location: ^5.0.3

# Bluetooth
flutter_blue_plus: ^1.20.0
permission_handler: ^11.1.0

# UI/UX
google_fonts: ^6.1.0
flutter_svg: ^2.0.9
lottie: ^2.7.0

# Utils
shared_preferences: ^2.2.2
uuid: ^4.2.1
intl: ^0.19.0
```

---

## Project Structure

```
lib/
├── main.dart                      # App entry point, Amplify configuration
├── amplifyconfiguration.dart      # AWS Amplify config (auto-generated)
│
├── core/                          # Core application infrastructure
│   ├── constants/
│   │   └── app_constants.dart     # App constants, BLE UUIDs, keys
│   ├── theme/
│   │   └── app_theme.dart         # Material 3 theme, colors, typography
│   └── utils/
│       └── validators.dart        # Input validation utilities
│
├── models/                        # Data models
│   ├── user_model.dart            # User profile data
│   ├── contact_model.dart         # Emergency contact model
│   └── device_model.dart          # BLE device model
│
├── providers/                     # State management (Provider pattern)
│   ├── auth_provider.dart         # Authentication state & logic
│   ├── ble_provider.dart          # BLE connection state
│   └── sos_provider.dart          # SOS activation state
│
├── services/                      # Business logic & external services
│   ├── auth_service.dart          # AWS Cognito auth operations
│   ├── location_service.dart      # GPS & location tracking
│   ├── esp32_ble_service.dart     # BLE communication with ESP32
│   ├── sos_routing_service.dart   # SOS routing decision engine
│   ├── emergency_service.dart     # Emergency contact management
│   ├── connectivity_service.dart  # Network state monitoring
│   ├── gps_availability_service.dart  # GPS status checks
│   └── otp_service.dart           # OTP operations
│
├── screens/                       # UI Screens
│   ├── splash_screen.dart
│   ├── register_phone_screen.dart
│   ├── otp_verification_screen.dart
│   ├── user_details_screen.dart
│   ├── home_dashboard_screen.dart
│   ├── sos_active_screen.dart
│   ├── device_pairing_screen.dart
│   ├── device_status_screen.dart
│   ├── emergency_contacts_screen.dart
│   ├── sos_message_editor_screen.dart
│   ├── location_privacy_screen.dart
│   ├── permissions_screen.dart
│   ├── profile_screen.dart
│   └── settings_screen.dart
│
├── features/                      # Feature-based organization (newer code)
│   └── auth/
│       ├── screens/
│       │   ├── login_screen.dart
│       │   └── register_screen.dart
│       └── services/
│           └── auth_service.dart
│
├── widgets/                       # Reusable UI widgets
│   ├── primary_button.dart
│   ├── sos_button.dart
│   └── info_card.dart
│
└── shared/
    └── widgets/
        └── custom_text_field.dart
```

---

## Build and Run Commands

### Prerequisites
- Flutter SDK >= 3.2.0
- Android SDK (for Android builds)
- Xcode (for iOS builds)
- AWS Amplify CLI (for backend updates)

### Development Commands

```bash
# Get dependencies
flutter pub get

# Run in debug mode
flutter run

# Run on specific device
flutter run -d <device_id>

# Build APK (Android)
flutter build apk

# Build App Bundle (Android Play Store)
flutter build appbundle

# Build iOS
flutter build ios

# Analyze code
flutter analyze

# Run tests
flutter test
```

### Platform-Specific Setup

#### Android
The app requires the following permissions in `android/app/src/main/AndroidManifest.xml`:
- `INTERNET`, `ACCESS_NETWORK_STATE`
- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`
- `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE`
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`
- `CALL_PHONE`, `VIBRATE`, `POST_NOTIFICATIONS`

#### iOS
Ensure the following keys are set in `ios/Runner/Info.plist`:
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`
- `NSBluetoothAlwaysUsageDescription`

---

## Code Style Guidelines

### Dart/Flutter Conventions
- Follow the [Flutter style guide](https://github.com/flutter/flutter/blob/master/docs/contributing/Style-guide-for-Flutter-repo.md)
- Use `flutter_lints` package for linting (enabled in `analysis_options.yaml`)
- Line length: 80-100 characters (prefer readability)

### Naming Conventions
| Type | Convention | Example |
|------|------------|---------|
| Files | snake_case | `auth_provider.dart` |
| Classes | PascalCase | `AuthProvider` |
| Variables/Functions | camelCase | `isLoading`, `signIn()` |
| Constants | SCREAMING_SNAKE_CASE or camelCase | `primaryBlue` |
| Private members | _prefix | `_isLoading` |

### Architecture Patterns
1. **Provider Pattern**: Use `ChangeNotifier` for reactive state management
2. **Service Layer**: Business logic in services, UI only handles presentation
3. **Model Classes**: Use `fromJson()`/`toJson()` for serialization
4. **Constants**: Centralize in `app_constants.dart`

### Code Organization
- Group imports: Dart/Flutter → Packages → Relative imports
- Use trailing commas for better formatting
- Prefer `const` constructors where possible
- Use `safePrint()` from Amplify instead of `print()` for production

---

## Testing Instructions

### Running Tests
```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/auth_test.dart
```

### Test Structure
The project follows standard Flutter testing:
- Unit tests: Business logic in `services/`
- Widget tests: UI components in `screens/` and `widgets/`
- Integration tests: Full user flows (if available)

### Manual Testing Checklist
- [ ] OTP authentication flow (sign up → verify → sign in)
- [ ] BLE device pairing and connection
- [ ] SOS trigger from app and ESP32 device
- [ ] Location permissions and GPS tracking
- [ ] Emergency contact CRUD operations
- [ ] Offline behavior (no internet)

---

## Security Considerations

### Authentication
- **Passwordless OTP**: Uses AWS Cognito custom authentication flow
- **Secure Storage**: Device pairing ID stored in `SharedPreferences` (encrypted on modern Android)
- **Session Management**: Auto-refresh via Amplify Hub events

### Location Privacy
- **Privacy-First**: Location is ONLY tracked when SOS is active
- **Background Location**: Disabled in current demo version (see comments in `location_service.dart`)
- **User Consent**: Explicit permission requests for all sensitive operations

### BLE Security
- BLE UUIDs are hardcoded in `app_constants.dart` (replace with production values)
- Auto-reconnect only to previously paired devices
- Connection state monitoring for disconnections

### Data Handling
- User profile stored in AWS AppSync (GraphQL)
- Emergency contacts stored locally with `SharedPreferences`
- No PII logging (use `safePrint()`)

---

## Key Architectural Decisions

### SOS Routing Logic
The `SosRoutingService` implements a decision engine that determines:
1. **Sender**: Phone SIM vs ESP eSIM
2. **Location Source**: Phone GPS vs ESP GPS

Based on:
- ESP connection status (BLE)
- Phone internet availability
- ESP GPS availability

See detailed truth tables in `lib/services/sos_routing_service.dart`.

### State Management
- **AuthProvider**: Manages sign-in state, OTP flow, user details
- **BleProvider**: Manages BLE connection, device scanning
- **SosProvider**: Manages SOS activation state, timer, live tracking

### Backend Integration
- AWS Amplify configured in `main.dart` with plugins for Auth and API
- Custom auth flow using Lambda triggers for OTP
- GraphQL API for user data persistence

---

## Common Development Tasks

### Adding a New Screen
1. Create file in `lib/screens/`
2. Use existing theme from `AppTheme.lightTheme`
3. Add navigation from appropriate entry point
4. Follow existing patterns for Provider usage

### Adding a New Service
1. Create file in `lib/services/`
2. Implement as singleton or inject via constructor
3. Add error handling with `try-catch`
4. Use `safePrint()` for debugging

### Modifying BLE Communication
1. Update UUIDs in `app_constants.dart` if needed
2. Modify `esp32_ble_service.dart` for protocol changes
3. Ensure backward compatibility with existing ESP32 firmware

### Updating Amplify Configuration
1. Use Amplify CLI: `amplify pull` or `amplify push`
2. Update `amplifyconfiguration.dart` (auto-generated)
3. Never commit sensitive credentials (use `.gitignore`)

---

## Known Limitations

1. **Google Maps**: Currently shows placeholder (API key required for production)
2. **Background Location**: Disabled for demo stability
3. **iOS BLE**: May require additional permission handling
4. **OTP**: Currently uses Lambda triggers (ensure AWS credits are available)

## Important Notes

### AWS Cognito Lambda Triggers Required
For the OTP flow to work, you must configure these Lambda triggers in your Cognito User Pool:
- **DefineAuthChallenge**: Defines the custom authentication flow
- **CreateAuthChallenge**: Sends the OTP via SMS (requires SNS permissions)
- **VerifyAuthChallenge**: Validates the OTP entered by user

Ensure your Lambda execution role has `sns:Publish` permission and your SNS spending limit is > $1.

---

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [AWS Amplify Flutter](https://docs.amplify.aws/flutter/)
- [Flutter Blue Plus](https://pub.dev/packages/flutter_blue_plus)
- [Provider Package](https://pub.dev/packages/provider)

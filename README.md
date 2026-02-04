# 🛡️ Suraksha+ - Personal Safety App

A comprehensive Flutter-based personal safety application featuring real-time location tracking, emergency alerts, Bluetooth connectivity with ESP32 devices, and Firebase integration.

---

## 📋 Table of Contents

- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Installation Guide](#-installation-guide)
  - [1. Install Flutter SDK](#1-install-flutter-sdk)
  - [2. Install Android Studio](#2-install-android-studio)
  - [3. Configure Android Studio](#3-configure-android-studio)
  - [4. Setup Firebase](#4-setup-firebase)
  - [5. Get Google Maps API Key](#5-get-google-maps-api-key)
- [Project Setup](#-project-setup)
- [Running the App](#-running-the-app)
- [Project Structure](#-project-structure)
- [Dependencies](#-dependencies)
- [Troubleshooting](#-troubleshooting)

---

## ✨ Features

- 🔐 **User Authentication** - Secure login/signup with Firebase Auth
- 📍 **Real-time Location Tracking** - GPS-based location services
- 🗺️ **Google Maps Integration** - Interactive maps for location visualization
- 📡 **Bluetooth Connectivity** - ESP32 BLE device integration
- 🚨 **Emergency Alerts** - Quick SOS functionality
- ☁️ **Cloud Storage** - Firebase Firestore for data persistence

---

## 📌 Prerequisites

Before you begin, ensure you have the following installed:

| Requirement | Version | Download Link |
|-------------|---------|---------------|
| Flutter SDK | 3.x or later | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart SDK | Included with Flutter | - |
| Android Studio | Latest | [developer.android.com](https://developer.android.com/studio) |
| Git | Latest | [git-scm.com](https://git-scm.com/downloads) |
| VS Code (Optional) | Latest | [code.visualstudio.com](https://code.visualstudio.com/) |

---

## 🚀 Installation Guide

### 1. Install Flutter SDK

#### Windows

```bash
# Download Flutter SDK from https://flutter.dev/docs/get-started/install/windows
# Extract to C:\src\flutter (or your preferred location)

# Add Flutter to PATH (System Environment Variables)
# Add: C:\src\flutter\bin

# Verify installation
flutter doctor
```

#### macOS

```bash
# Using Homebrew
brew install flutter

# Or download manually from https://flutter.dev/docs/get-started/install/macos

# Verify installation
flutter doctor
```

#### Linux

```bash
# Download from https://flutter.dev/docs/get-started/install/linux
# Extract and add to PATH

export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor
```

---

### 2. Install Android Studio

1. **Download Android Studio** from [developer.android.com/studio](https://developer.android.com/studio)

2. **Run the installer** and follow the setup wizard

3. **Install the following components**:
   - Android SDK
   - Android SDK Command-line Tools
   - Android SDK Build-Tools
   - Android SDK Platform-Tools
   - Android Emulator

---

### 3. Configure Android Studio

1. **Open Android Studio** → `Settings/Preferences` → `Plugins`

2. **Install Flutter Plugin**:
   - Search for "Flutter" → Install
   - This will also install the Dart plugin

3. **Configure Android SDK**:
   - Go to `Settings` → `Appearance & Behavior` → `System Settings` → `Android SDK`
   - Install Android SDK (API Level 33 or higher recommended)

4. **Set up an Android Emulator**:
   ```
   Tools → Device Manager → Create Device
   - Select a device (e.g., Pixel 6)
   - Select a system image (e.g., API 33)
   - Finish setup
   ```

5. **Accept Android Licenses**:
   ```bash
   flutter doctor --android-licenses
   ```

---

### 4. Setup Firebase

This project uses Firebase for authentication and database. To set it up:

1. **Create a Firebase Project**:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Click "Add Project" → Follow the setup wizard

2. **Add Android App to Firebase**:
   - Click the Android icon to add an Android app
   - Enter package name: `com.example.suraksha_plus` (or your package name)
   - Download `google-services.json`
   - Place it in `android/app/` directory

3. **Add iOS App to Firebase** (if building for iOS):
   - Click the iOS icon to add an iOS app
   - Download `GoogleService-Info.plist`
   - Place it in `ios/Runner/` directory

4. **Enable Authentication**:
   - Go to Firebase Console → Authentication → Sign-in method
   - Enable Email/Password authentication

5. **Enable Firestore**:
   - Go to Firebase Console → Firestore Database
   - Create database in test mode (or production with rules)

---

### 5. Get Google Maps API Key

1. **Go to** [Google Cloud Console](https://console.cloud.google.com/)

2. **Create a new project** or select existing

3. **Enable APIs**:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API (optional)

4. **Create API Key**:
   - Go to APIs & Services → Credentials
   - Create Credentials → API Key

5. **Add API Key to the project**:

   **For Android** (`android/app/src/main/AndroidManifest.xml`):
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
   ```

   **For iOS** (`ios/Runner/AppDelegate.swift`):
   ```swift
   GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
   ```

---

## 📦 Project Setup

### Clone the Repository

```bash
git clone https://github.com/Vansh13199/Suraksha.git
cd Suraksha
```

### Install Dependencies

```bash
# Get all Flutter packages
flutter pub get
```

### Verify Setup

```bash
# Check for any issues
flutter doctor -v
```

---

## ▶️ Running the App

### Run on Android Emulator

```bash
# List available emulators
flutter emulators

# Launch emulator
flutter emulators --launch <emulator_id>

# Run the app
flutter run
```

### Run on Physical Device

1. **Enable Developer Options** on your Android device
2. **Enable USB Debugging**
3. **Connect device via USB**
4. **Run**:
   ```bash
   flutter devices  # Verify device is connected
   flutter run
   ```

### Run with Hot Reload

```bash
flutter run
# Press 'r' for hot reload
# Press 'R' for hot restart
# Press 'q' to quit
```

### Build APK

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# APK location: build/app/outputs/flutter-apk/
```

### Build App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

---

## 📁 Project Structure

```
Suraksha+/
├── android/                 # Android-specific configuration
├── ios/                     # iOS-specific configuration
├── lib/                     # Main Dart source code
│   ├── main.dart           # App entry point
│   ├── screens/            # UI screens
│   ├── services/           # Business logic & API services
│   │   └── esp32_ble_service.dart  # ESP32 Bluetooth service
│   ├── models/             # Data models
│   ├── widgets/            # Reusable widgets
│   └── utils/              # Utility functions
├── assets/                  # Images, fonts, and other assets
├── pubspec.yaml            # Project dependencies
└── README.md               # This file
```

---

## 📚 Dependencies

| Package | Description |
|---------|-------------|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | User authentication |
| `cloud_firestore` | Cloud database |
| `google_maps_flutter` | Google Maps widget |
| `geolocator` | GPS location services |
| `flutter_blue_plus` | Bluetooth Low Energy (BLE) |
| `location` | Location services |
| `permission_handler` | Runtime permissions |
| `shared_preferences` | Local storage |
| `url_launcher` | Open URLs/links |
| `path_provider` | File system paths |

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Flutter Doctor Issues

```bash
flutter doctor -v
# Follow the suggestions to fix any issues
```

#### 2. Gradle Build Failed

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

#### 3. Android License Issues

```bash
flutter doctor --android-licenses
# Accept all licenses
```

#### 4. Firebase Configuration Missing

- Ensure `google-services.json` is in `android/app/`
- Ensure `GoogleService-Info.plist` is in `ios/Runner/`

#### 5. Bluetooth Permissions (Android)

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

#### 6. Location Permissions (Android)

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
```

---

## 📱 Minimum Requirements

- **Android**: API Level 21 (Android 5.0) or higher
- **iOS**: iOS 12.0 or higher
- **Bluetooth**: BLE 4.0+ supported device

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

**Vansh** - [GitHub Profile](https://github.com/Vansh13199)

---

<p align="center">Made with ❤️ using Flutter</p>

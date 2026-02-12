# Suraksha+ (Personal Safety App)

A Flutter application designed for personal safety, powered by AWS Amplify. It features secure phone authentication, persistent user sessions, and cloud-based user profile management.

## 🚀 Key Features

### 🔐 Authentication & Session
- **Phone Number Login (OTP)**: Secure, passwordless authentication using Amazon Cognito & AWS SNS.
- **Custom Auth Flow**: AWS Lambda triggers handle OTP generation and verification.
- **Persistent Login**: App automatically detects and restores user session on restart.
- **Intelligent Routing**: Splash screen directs users based on authentication status and profile completion (Home vs. Profile Setup).

### 👤 User Profile Management
- **Cloud Storage**: User details (Name, DOB, Gender, Blood Group) are stored securely in Amazon DynamoDB.
- **GraphQL API**: App communicates with the backend via AWS AppSync.
- **Self-Healing Data**: Automatically detects and fixes "zombie" user records (mismatched IDs) to ensure seamless login.

### 🆘 Emergency Features (In Progress)
- **Emergency Contacts**: Manage trusted contacts for SOS alerts.
- **SOS Button**: One-tap alert system with live location sharing.
- **Live Tracking**: Real-time location updates via OpenStreetMap.

## 🛠 Tech Stack

- **Frontend**: Flutter (Dart)
    - State Management: `Provider`
    - Maps: `flutter_map` (OpenStreetMap)
- **Backend**: AWS Amplify
    - **Auth**: Amazon Cognito (User Pools)
    - **API**: AWS AppSync (GraphQL)
    - **Database**: Amazon DynamoDB
    - **Functions**: AWS Lambda (Node.js)
    - **Notifications**: AWS SNS (Transactional SMS)

## 📦 Setup Instructions

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/your-username/suraksha-plus.git
    cd suraksha-plus
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Configure Amplify Backend**
    - Ensure you have the [Amplify CLI](https://docs.amplify.aws/cli/start/install/) installed.
    - Pull the backend environment (requires access to the AWS account):
    ```bash
    amplify pull --appId <YOUR_APP_ID> --envName <YOUR_ENV_NAME>
    ```

4.  **Run the App**
    ```bash
    flutter run
    ```

## 📂 Project Structure

- `lib/main.dart`: Entry point.
- `lib/screens/`: UI Screens (Splash, Login, OTP, Home, Profile).
- `lib/services/`: Backend integration logic (`AuthService`).
- `lib/providers/`: State management (`AuthProvider`).
- `lib/models/`: Data models (`UserModel`).
- `amplify/backend/`: AWS Backend configuration (CloudFormation, GraphQL Schema, Lambda Functions).

# Technical Specification: AWS SNS Integration (SMS/OTP Delivery)

## Overview
The **Suraksha+ SMS Delivery Subsystem** utilizes **AWS Simple Notification Service (SNS)** as its primary backbone for low-latency, mission-critical communication. This integration facilitates two essential security requirements: **Passwordless User Authentication** and **Emergency Contact Alerting**.

## 🏗️ Subsystem Architecture

```mermaid
graph LR
    A[Mobile Client] -->|Login Request| B[AWS Cognito]
    B -->|Trigger: CreateAuthChallenge| C[Lambda: CreateAuthChallenge]
    C -->|AWS SDK v3: PublishCommand| D[AWS SNS]
    D -->|SMS (ap-northeast-3)| E[User Device]

    F[ESP32 Hardware] -->|Trigger /sos/trigger| G[Lambda: suraksha0dd005c5]
    G -->|Fetch Contacts| H[DynamoDB]
    G -->|AWS SDK v3: PublishCommand| D
    D -->|SMS (ap-northeast-3)| I[Emergency Contacts]
```

## 📋 Integration Modules

### 1. 🔐 Custom Challenge Auth (OTP)
The authentication flow is implemented as a **Cognito Custom Challenge**.
-   **Trigger**: `surakshab48b52dfb48b52dfCreateAuthChallenge`.
-   **Operation**: The Lambda generates a cryptographically random 6-digit integer and utilizes the SNS `PublishCommand` to dispatch it. 
-   **Code Persistence**: The OTP is stored in the `PrivateChallengeParameters` for verification by the subsequent `VerifyAuthChallengeResponse` trigger.

### 2. 🚨 Mission-Critical Alerting (SOS)
During an SOS session, the subsystem coordinates multi-contact alerting.
-   **REST API Mapping**: Integrated via Amazon API Gateway to the `/sos` path.
-   **Operational Flow**: The backend fetches contact associations for the designated `userId` and maps the SNS `PublishCommand` across the result shard.
-   **Redundancy**: The protocol targets multiple contacts simultaneously to minimize single-point-of-failure risks in responder availability.

## 📡 Networking & Security

### Regional Strategy
To ensure optimal throughput and bypass regional service quotas, the **`ap-northeast-3` (Osaka)** region is utilized for SNS clients. This decoupling from the primary `ap-south-1` region provides both geographical redundancy and dedicated SMS transactional capacity.

### IAM Policy Specification
The Lambda execution roles strictly adhere to the Principle of Least Privilege (PoLP), restricted to `sns:Publish` actions:

```json
{
  "Effect": "Allow",
  "Action": "sns:Publish",
  "Resource": "*"
}
```

## 🔬 Operational Considerations for Research
In a real-world deployment scenario, the SNS subsystem must transition from the **AWS SMS Sandbox** to production. During research and prototyping, destination numbers must be pre-verified. The system handles **Transactional** message types by default to prioritize delivery speed over cost, essential for time-sensitive emergency alerts.

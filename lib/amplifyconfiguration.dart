const amplifyconfig = '''{
    "UserAgent": "aws-amplify-cli/2.0",
    "Version": "1.0",
    "api": {
        "plugins": {
            "awsAPIPlugin": {
                "android": {
                    "endpointType": "GraphQL",
                    "endpoint": "https://ruh4ndog7zcqtmrhdaxuq6hmra.appsync-api.ap-south-1.amazonaws.com/graphql",
                    "region": "ap-south-1",
                    "authorizationType": "API_KEY",
                    "apiKey": "da2-2oqmyory5jejldfnrnzbs4gnwa"
                }
            }
        }
    },
    "auth": {
        "plugins": {
            "awsCognitoAuthPlugin": {
                "UserAgent": "aws-amplify-cli/0.1.0",
                "Version": "0.1.0",
                "IdentityManager": {
                    "Default": {}
                },
                "AppSync": {
                    "Default": {
                        "ApiUrl": "https://ruh4ndog7zcqtmrhdaxuq6hmra.appsync-api.ap-south-1.amazonaws.com/graphql",
                        "Region": "ap-south-1",
                        "AuthMode": "API_KEY",
                        "ApiKey": "da2-2oqmyory5jejldfnrnzbs4gnwa",
                        "ClientDatabasePrefix": "android_API_KEY"
                    }
                },
                "CredentialsProvider": {
                    "CognitoIdentity": {
                        "Default": {
                            "PoolId": "ap-south-1:323f1ea0-389d-4cc6-8fbc-a0bd47c3e8b1",
                            "Region": "ap-south-1"
                        }
                    }
                },
                "CognitoUserPool": {
                    "Default": {
                        "PoolId": "ap-south-1_A5dYGSMKp",
                        "AppClientId": "1rk5v3e8s7q679kafb25f2vb8h",
                        "Region": "ap-south-1"
                    }
                },
                "Auth": {
                    "Default": {
                        "authenticationFlowType": "CUSTOM_AUTH",
                        "mfaConfiguration": "OFF",
                        "mfaTypes": [
                            "SMS"
                        ],
                        "passwordProtectionSettings": {
                            "passwordPolicyMinLength": 8,
                            "passwordPolicyCharacters": []
                        },
                        "signupAttributes": [
                            "PHONE_NUMBER"
                        ],
                        "socialProviders": [],
                        "usernameAttributes": [
                            "PHONE_NUMBER"
                        ],
                        "verificationMechanisms": [
                            "PHONE_NUMBER"
                        ]
                    }
                }
            }
        }
    }
}''';

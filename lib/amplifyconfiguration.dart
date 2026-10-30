const amplifyconfig = '''{
    "UserAgent": "aws-amplify-cli/2.0",
    "Version": "1.0",
    "api": {
        "plugins": {
            "awsAPIPlugin": {
                "sosapi": {
                    "endpointType": "REST",
                    "endpoint": "https://uuanokhji9.execute-api.ap-south-1.amazonaws.com/prod",
                    "region": "ap-south-1",
                    "authorizationType": "AWS_IAM"
                },
                "suraksha": {
                    "endpointType": "GraphQL",
                    "endpoint": "https://3mulfjxwcrhwlkjvksifbi4qvu.appsync-api.ap-south-1.amazonaws.com/graphql",
                    "region": "ap-south-1",
                    "authorizationType": "AMAZON_COGNITO_USER_POOLS",
                    "apiKey": "da2-cve7m3e43vfzdau4plzmszbupq"
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
                        "ApiUrl": "https://3mulfjxwcrhwlkjvksifbi4qvu.appsync-api.ap-south-1.amazonaws.com/graphql",
                        "Region": "ap-south-1",
                        "AuthMode": "AMAZON_COGNITO_USER_POOLS",
                        "ClientDatabasePrefix": "suraksha_AMAZON_COGNITO_USER_POOLS"
                    }
                },
                "CredentialsProvider": {
                    "CognitoIdentity": {
                        "Default": {
                            "PoolId": "ap-south-1:e26bc5c3-e7ce-4c41-8c1d-5635449ab8c1",
                            "Region": "ap-south-1"
                        }
                    }
                },
                "CognitoUserPool": {
                    "Default": {
                        "PoolId": "ap-south-1_IrCwWGqNy",
                        "AppClientId": "56l4os172lbsgvk5cjn5u7c2d5",
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
                            "EMAIL"
                        ],
                        "socialProviders": [],
                        "usernameAttributes": [
                            "EMAIL"
                        ],
                        "verificationMechanisms": [
                            "EMAIL"
                        ]
                    }
                },
                "S3TransferUtility": {
                    "Default": {
                        "Bucket": "suraksha-storage-prod-new",
                        "Region": "ap-south-1"
                    }
                }
            }
        }
    },
    "storage": {
        "plugins": {
            "awsS3StoragePlugin": {
                "bucket": "suraksha-storage-prod-new",
                "region": "ap-south-1",
                "defaultAccessLevel": "guest"
            }
        }
    }
}''';

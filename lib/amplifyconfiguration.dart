const amplifyconfig = '''{
    "UserAgent": "aws-amplify-cli/2.0",
    "Version": "1.0",
    "api": {
        "plugins": {
            "awsAPIPlugin": {
                "sosapi": {
                    "endpointType": "REST",
                    "endpoint": "https://es0tbyl9y0.execute-api.ap-south-1.amazonaws.com/dev",
                    "region": "ap-south-1",
                    "authorizationType": "AWS_IAM"
                },
                "suraksha": {
                    "endpointType": "GraphQL",
                    "endpoint": "https://jmvhy4clwzannjvummuqel4yy4.appsync-api.ap-south-1.amazonaws.com/graphql",
                    "region": "ap-south-1",
                    "authorizationType": "AMAZON_COGNITO_USER_POOLS",
                    "apiKey": "da2-x244aarcpzbw3bdn4zvnm4jqfu"
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
                "CredentialsProvider": {
                    "CognitoIdentity": {
                        "Default": {
                            "PoolId": "ap-south-1:c28fd02c-5ca2-4ef4-9789-1f9a27abcba0",
                            "Region": "ap-south-1"
                        }
                    }
                },
                "CognitoUserPool": {
                    "Default": {
                        "PoolId": "ap-south-1_iFJ06Qql9",
                        "AppClientId": "3qqf9oks1m83c0vbhk7mqlvlqr",
                        "Region": "ap-south-1"
                    }
                },
                "Auth": {
                    "Default": {
                        "authenticationFlowType": "CUSTOM_AUTH",
                        "socialProviders": [],
                        "usernameAttributes": [
                            "PHONE_NUMBER"
                        ],
                        "signupAttributes": [
                            "PHONE_NUMBER"
                        ],
                        "passwordProtectionSettings": {
                            "passwordPolicyMinLength": 8,
                            "passwordPolicyCharacters": []
                        },
                        "mfaConfiguration": "OFF",
                        "mfaTypes": [
                            "SMS"
                        ],
                        "verificationMechanisms": [
                            "PHONE_NUMBER"
                        ]
                    }
                },
                "AppSync": {
                    "Default": {
                        "ApiUrl": "https://jmvhy4clwzannjvummuqel4yy4.appsync-api.ap-south-1.amazonaws.com/graphql",
                        "Region": "ap-south-1",
                        "AuthMode": "AMAZON_COGNITO_USER_POOLS",
                        "ClientDatabasePrefix": "suraksha_AMAZON_COGNITO_USER_POOLS"
                    }
                }
            }
        }
    }
}''';

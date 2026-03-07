/* Amplify Params - DO NOT EDIT
    ENV
    REGION
    AUTH_SURAKSHA5B7EE2495B7EE249_USERPOOLID
Amplify Params - DO NOT EDIT */

const { SNSClient, PublishCommand } = require("@aws-sdk/client-sns");
const {
    CognitoIdentityProviderClient,
    AdminCreateUserCommand,
    AdminSetUserPasswordCommand,
    AdminUpdateUserAttributesCommand
} = require("@aws-sdk/client-cognito-identity-provider");

const REGION = process.env.REGION;
const USER_POOL_ID = process.env.AUTH_SURAKSHA5B7EE2495B7EE249_USERPOOLID;

const snsClient = new SNSClient({ region: REGION });
const cognitoClient = new CognitoIdentityProviderClient({ region: REGION });

exports.handler = async (event) => {
    console.log("EVENT: " + JSON.stringify(event));

    // Enable CORS for all responses
    const headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "*"
    };

    let body;
    try {
        if (event.body) {
            body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
        } else {
            body = event; // Fallback for direct invocation
        }
    } catch (e) {
        console.error("JSON PARSE ERROR:", e);
        return {
            statusCode: 400,
            body: JSON.stringify({ error: "Invalid JSON body", details: e.message }),
            headers: headers
        };
    }

    // DISPATCHER: Check for 'action'
    if (body.action === 'signup') {
        return await handleSignUp(body, headers);
    } else {
        // Default to SOS SMS logic
        return await handleSosSms(body, headers);
    }
};

async function handleSignUp(body, headers) {
    const { phoneNumber, password } = body;

    if (!phoneNumber || !password) {
        return {
            statusCode: 400,
            body: JSON.stringify({ error: "Missing phoneNumber or password" }),
            headers: headers
        };
    }

    try {
        console.log(`[SIGNUP] Creating user ${phoneNumber}...`);

        // 1. Create User (MessageAction: SUPPRESS prevents default email/sms)
        await cognitoClient.send(new AdminCreateUserCommand({
            UserPoolId: USER_POOL_ID,
            Username: phoneNumber,
            TemporaryPassword: password,
            UserAttributes: [
                { Name: 'phone_number', Value: phoneNumber },
                { Name: 'phone_number_verified', Value: 'true' } // Auto-verify phone
            ],
            MessageAction: 'SUPPRESS'
        }));

        console.log(`[SIGNUP] Setting permanent password for ${phoneNumber}...`);

        // 2. Set Permanent Password (confirms the user status from FORCE_CHANGE_PASSWORD to CONFIRMED)
        await cognitoClient.send(new AdminSetUserPasswordCommand({
            UserPoolId: USER_POOL_ID,
            Username: phoneNumber,
            Password: password,
            Permanent: true
        }));

        console.log(`[SIGNUP] Success for ${phoneNumber}`);

        return {
            statusCode: 200,
            body: JSON.stringify({ success: true, message: "User created and confirmed" }),
            headers: headers
        };

    } catch (error) {
        console.error("[SIGNUP] Error:", error);

        // If user already exists, that's fine, we return 200 so UI can proceed to SignIn
        if (error.name === 'UsernameExistsException') {
            console.log("[SIGNUP] User already exists, proceeding.");
            return {
                statusCode: 200,
                body: JSON.stringify({ success: true, message: "User already exists", existing: true }),
                headers: headers
            };
        }

        return {
            statusCode: 500,
            body: JSON.stringify({ error: "SignUp failed", details: error.message }),
            headers: headers
        };
    }
}

async function handleSosSms(body, headers) {
    const contacts = body.contacts || [];
    const message = body.message || "SOS! I need help.";

    if (!contacts || contacts.length === 0) {
        console.warn("NO CONTACTS PROVIDED");
        return {
            statusCode: 400,
            body: JSON.stringify({ error: "No contacts provided" }),
            headers: headers
        };
    }

    // Send SMS to each contact
    const promises = contacts.map(phone => {
        const params = {
            Message: message,
            PhoneNumber: phone,
            MessageAttributes: {
                'AWS.SNS.SMS.SMSType': {
                    DataType: 'String',
                    StringValue: 'Transactional'
                }
            }
        };
        return snsClient.send(new PublishCommand(params));
    });

    try {
        const results = await Promise.all(promises);
        console.log("SMS SENT SUCCESSFULLY:", results);
        return {
            statusCode: 200,
            body: JSON.stringify({ success: true, count: contacts.length }),
            headers: headers
        };
    } catch (err) {
        console.error("SMS SEND FAILURE:", err);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: "Failed to send SMS", details: err.message }),
            headers: headers
        };
    }
}

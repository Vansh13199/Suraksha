/* Amplify Params - DO NOT EDIT
    ENV
    REGION
Amplify Params - DO NOT EDIT */

const AWS = require('aws-sdk');
const sns = new AWS.SNS({ region: 'ap-northeast-3' }); // Osaka Region for SMS

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
        return sns.publish(params).promise();
    });

    try {
        const results = await Promise.all(promises);
        console.log("SMS SENT SUCCESSFULLY:", results);
        return {
            statusCode: 200,
            body: JSON.stringify({ success: true, count: contacts.length, results: results }),
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
};

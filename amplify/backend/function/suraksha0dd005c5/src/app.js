/*
Copyright 2017 - 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
    http://aws.amazon.com/apache2.0/
or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.
*/




const express = require('express')
const bodyParser = require('body-parser')
const awsServerlessExpressMiddleware = require('aws-serverless-express/middleware')

const { 
  CognitoIdentityProviderClient, 
  AdminCreateUserCommand,
  AdminSetUserPasswordCommand
} = require("@aws-sdk/client-cognito-identity-provider");

const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, ScanCommand, QueryCommand } = require("@aws-sdk/lib-dynamodb");
const { SNSClient, PublishCommand } = require("@aws-sdk/client-sns");

const region = process.env.REGION || 'ap-south-1';
const client = new CognitoIdentityProviderClient({ region });
const ddbClient = new DynamoDBClient({ region });
const ddbDocClient = DynamoDBDocumentClient.from(ddbClient);
const snsClient = new SNSClient({ region: 'ap-northeast-3' });

// declare a new express app
const app = express()
app.use(bodyParser.json())
app.use(awsServerlessExpressMiddleware.eventContext())

// Enable CORS for all methods
app.use(function(req, res, next) {
  res.header("Access-Control-Allow-Origin", "*")
  res.header("Access-Control-Allow-Headers", "*")
  next()
});


/**********************
 * Example get method *
 **********************/

app.get('/sos', function(req, res) {
  // Add your code here
  res.json({success: 'get call succeed!', url: req.url});
});

app.get('/sos/*', function(req, res) {
  // Add your code here
  res.json({success: 'get call succeed!', url: req.url});
});

/****************************
* Example post method *
****************************/

app.post('/sos', async function(req, res) {
  try {
    const { action, phoneNumber, password, contacts, message } = req.body;
    
    // 1. Handle Flutter Manual SOS (Send SMS via SNS)
    if (contacts && Array.isArray(contacts) && message) {
      console.log(`[SOS-MANUAL] Dispatching to ${contacts.length} contacts`);
      let sentCount = 0;
      const dispatchPromises = contacts.map(async (phone) => {
        try {
          await snsClient.send(new PublishCommand({
            PhoneNumber: phone,
            Message: message
          }));
          sentCount++;
        } catch (e) {
          console.error(`[SOS-MANUAL] SNS Failed for ${phone}:`, e);
        }
      });
      await Promise.all(dispatchPromises);
      return res.json({ success: true, contactsSent: sentCount });
    }

    // 2. Handle Authentication Sign-up
    if (action === 'signup') {
      // Find the UserPoolId from environment variables
      let userPoolId = process.env[Object.keys(process.env).find(k => k.endsWith('_USERPOOLID'))];
      if (!userPoolId) { userPoolId = 'ap-south-1_iFJ06Qql9'; }

      try {
        await client.send(new AdminCreateUserCommand({
          UserPoolId: userPoolId,
          Username: phoneNumber,
          UserAttributes: [{ Name: 'phone_number', Value: phoneNumber }],
          MessageAction: 'SUPPRESS'
        }));
      } catch (e) {
        if (e.name !== 'UsernameExistsException') throw e;
      }

      await client.send(new AdminSetUserPasswordCommand({
        UserPoolId: userPoolId,
        Username: phoneNumber,
        Password: password,
        Permanent: true
      }));

      return res.json({ success: 'User ready!', phoneNumber });
    }
    
    res.json({ success: 'post call succeed!', url: req.url, body: req.body });
  } catch (err) {
    console.error("SOS/Auth Error:", err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * STANDALONE SOS TRIGGER (called by ESP32)
 * Body: { phoneNumber, sessionId, latitude, longitude }
 * This endpoint now handles EVERYTHING:
 * 1. Creates SOSSession in DynamoDB
 * 2. Looks up emergency contacts
 * 3. Sends SMS via SNS
 */
app.post('/sos/trigger', async function(req, res) {
  try {
    const { phoneNumber, sessionId, latitude, longitude } = req.body;
    console.log(`[SOS] Trigger for ${phoneNumber}, session ${sessionId}, lat=${latitude}, lon=${longitude}`);

    if (!phoneNumber || !sessionId) {
      return res.status(400).json({ error: "Missing phoneNumber or sessionId" });
    }

    // Table names from environment or hardcoded fallback
    let userTable = process.env.USER_TABLE || `User-vkqykgibazglvo3pdfkgqgetfu-${process.env.ENV}`;
    let contactTable = process.env.CONTACT_TABLE || `EmergencyContact-vkqykgibazglvo3pdfkgqgetfu-${process.env.ENV}`;
    const sosTable = process.env.SOS_TABLE || `SOSSession-vkqykgibazglvo3pdfkgqgetfu-${process.env.ENV}`;

    console.log(`[SOS-ENVIRONMENT] UserTable: ${userTable}, Env: ${process.env.ENV}`);

    // 1. Create SOSSession in DynamoDB
    const now = new Date().toISOString();
    const { PutCommand } = require("@aws-sdk/lib-dynamodb");
    await ddbDocClient.send(new PutCommand({
      TableName: sosTable,
      Item: {
        id: sessionId,
        phoneNumber: phoneNumber,
        isActive: true,
        latitude: parseFloat(latitude) || 0,
        longitude: parseFloat(longitude) || 0,
        __typename: "SOSSession",
        createdAt: now,
        updatedAt: now,
        owner: phoneNumber
      }
    }));
    console.log(`[SOS] Session ${sessionId} created.`);

    // 2. Find User by Phone Number (Normalize: remove spaces/dashes)
    let searchPhone = phoneNumber.replace(/[\s-]/g, '');
    let searchPhoneWithPlus = searchPhone.startsWith('+') ? searchPhone : `+${searchPhone}`;
    let searchPhoneWithoutPlus = searchPhone.startsWith('+') ? searchPhone.substring(1) : searchPhone;

    console.log(`[SOS-SEARCH] Searching User with: ${searchPhoneWithPlus} OR ${searchPhoneWithoutPlus}`);
    
    // Using OR to handle database inconsistencies (+91 vs 91)
    const userResult = await ddbDocClient.send(new ScanCommand({
      TableName: userTable,
      FilterExpression: "phoneNumber = :p1 OR phoneNumber = :p2",
      ExpressionAttributeValues: { 
        ":p1": searchPhoneWithPlus,
        ":p2": searchPhoneWithoutPlus
      }
    }));

    console.log(`[SOS-DB] User query found ${userResult.Items ? userResult.Items.length : 0} items`);

    if (!userResult.Items || userResult.Items.length === 0) {
      console.warn(`[SOS-FAIL] User profile not found for: ${searchPhone}`);
      return res.json({ 
        success: true, 
        sessionCreated: true, 
        contactsSent: 0, 
        note: "User Profile not found map." 
      });
    }

    const userData = userResult.Items[0];
    const userId = userData.id;
    const userName = `${userData.firstName || ''} ${userData.lastName || ''}`.trim() || searchPhoneWithPlus;

    console.log(`[SOS-USER] Identified: ${userName} (ID: ${userId})`);

    // 3. Find Emergency Contacts for this specific User ID
    console.log(`[SOS] Searching contacts for UserID: ${userId}`);
    const contactResult = await ddbDocClient.send(new ScanCommand({
      TableName: contactTable,
      FilterExpression: "userId = :u",
      ExpressionAttributeValues: { ":u": userId }
    }));

    const contacts = contactResult.Items || [];
    console.log(`[SOS-DB] Found ${contacts.length} emergency contacts.`);

    // 4. Send SMS Alert via SNS
    const trackingUrl = `https://suraksha.dev-vansh.in/?session=${sessionId}`;
    const smsMessage = `🚨 SOS ALERT! ${userName} is in danger. Track live here: ${trackingUrl}`;

    let sentCount = 0;
    const dispatchPromises = contacts.map(async (contact) => {
      try {
        console.log(`[SOS] Dispatching SMS to ${contact.phoneNumber}`);
        await snsClient.send(new PublishCommand({
          PhoneNumber: contact.phoneNumber,
          Message: smsMessage
        }));
        sentCount++;
      } catch (e) {
        console.error(`[SOS] SNS Failed for ${contact.phoneNumber}:`, e);
      }
    });

    await Promise.all(dispatchPromises);

    res.json({ 
      success: true, 
      sessionCreated: true,
      userName: userName,
      contactsFound: contacts.length,
      contactsSent: sentCount,
      trackingUrl 
    });

  } catch (err) {
    console.error("[SOS] Trigger Error:", err);
    res.status(500).json({ error: err.message });
  }
});

app.post('/sos/stop', async function(req, res) {
  try {
    const { sessionId } = req.body;
    console.log(`[SOS] Stop request for session ${sessionId}`);

    if (!sessionId) {
      return res.status(400).json({ error: "Missing sessionId" });
    }

    const sosTable = process.env.SOS_TABLE || `SOSSession-vkqykgibazglvo3pdfkgqgetfu-${process.env.ENV}`;
    const { UpdateCommand } = require("@aws-sdk/lib-dynamodb");

    await ddbDocClient.send(new UpdateCommand({
      TableName: sosTable,
      Key: { id: sessionId },
      UpdateExpression: "set isActive = :status",
      ExpressionAttributeValues: {
        ":status": false
      }
    }));

    console.log(`[SOS] Session ${sessionId} stopped successfully.`);
    res.json({ success: true, sessionStopped: true });

  } catch (err) {
    console.error("[SOS] Stop Error:", err);
    res.status(500).json({ error: err.message });
  }
});

/****************************
* Example put method *
****************************/

app.put('/sos', function(req, res) {
  // Add your code here
  res.json({success: 'put call succeed!', url: req.url, body: req.body})
});

app.put('/sos/*', function(req, res) {
  // Add your code here
  res.json({success: 'put call succeed!', url: req.url, body: req.body})
});

/****************************
* Example delete method *
****************************/

app.delete('/sos', function(req, res) {
  // Add your code here
  res.json({success: 'delete call succeed!', url: req.url});
});

app.delete('/sos/*', function(req, res) {
  // Add your code here
  res.json({success: 'delete call succeed!', url: req.url});
});

app.listen(3000, function() {
    console.log("App started")
});

// Export the app object. When executing the application local this does nothing. However,
// to port it to AWS Lambda we will create a wrapper around that will load the app from
// this file
module.exports = app

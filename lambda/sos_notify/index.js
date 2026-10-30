const { DynamoDBClient, ScanCommand } = require('@aws-sdk/client-dynamodb');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const USER_TABLE = process.env.USER_TABLE_NAME || 'User-newprod-prod';
const KEY_PATH = path.join(__dirname, 'service-account.json');

/**
 * Signs a JWT for Google OAuth2 using built-in Node.js crypto (no dependencies!)
 */
async function getAccessToken(key) {
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 3600;

  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: key.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: exp,
    iat: iat
  };

  const toSign = Buffer.from(JSON.stringify(header)).toString('base64url') + '.' +
    Buffer.from(JSON.stringify(payload)).toString('base64url');

  const sign = crypto.createSign('RSA-SHA256');
  sign.update(toSign);
  const signature = sign.sign(key.private_key, 'base64url');
  const jwt = toSign + '.' + signature;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
  });

  const data = await res.json();
  return data.access_token;
}

exports.handler = async (event) => {
  console.log('--- 🚀 STARTING ZERO-DEP SOS NOTIFIER ---');

  // Load Key
  let keyContent;
  try {
    keyContent = JSON.parse(fs.readFileSync(KEY_PATH, 'utf8'));
  } catch (e) {
    console.error('❌ ERROR: Failed to read service-account.json:', e.message);
    return { statusCode: 500 };
  }

  const projectId = keyContent.project_id || process.env.FIREBASE_PROJECT_ID || 'surskah-maps';
  console.log(`🎯 Using Firebase Project ID: ${projectId}`);

  // Auth Pre-fetch
  let accessToken;
  try {
    console.log('🔍 Generating OAuth2 Token...');
    accessToken = await getAccessToken(keyContent);
    console.log('✅ Token Generated');
  } catch (e) {
    console.error('❌ ERROR: Auth failed:', e.message);
    return { statusCode: 500 };
  }

  const dynamodb = new DynamoDBClient({});

  for (const record of event.Records) {
    if (record.eventName !== 'INSERT') continue;

    const newImage = record.dynamodb.NewImage;
    const sessionId = newImage.id.S;
    const senderPhone = newImage.phoneNumber?.S || 'Someone';
    const triggerType = newImage.triggerType?.S || 'MANUAL';

    const targetPhones = [];
    if (newImage.authorizedViewers?.L) {
      newImage.authorizedViewers.L.forEach(v => { if (v.S) targetPhones.push(v.S); });
    }

    console.log(`🛎️  SOS from ${senderPhone} (Session: ${sessionId})`);

    const senderDigits = senderPhone.replace(/\D/g, '').slice(-10);

    for (const rawPhone of targetPhones) {
      const viewerDigits = rawPhone.replace(/\D/g, '').slice(-10);

      // 🕵️ SKIP SENDER (No-Echo Filter)
      if (viewerDigits === senderDigits) {
        console.log(`ℹ️ Skipping notification for sender: ${rawPhone}`);
        continue;
      }

      try {
        console.log(`🔍 DB Lookup for ${rawPhone}...`);
        const scanRes = await dynamodb.send(new ScanCommand({ TableName: USER_TABLE }));
        const user = scanRes.Items?.find(item => {
          const dbDigits = (item.phoneNumber?.S || '').replace(/\D/g, '');
          return dbDigits.endsWith(viewerDigits);
        });

        if (user?.fcmTokens?.L?.length > 0) {
          const tokens = user.fcmTokens.L.map(t => t.S).filter(t => t);
          console.log(`📱 Sending pushes to ${tokens.length} devices...`);

          for (const token of tokens) {
            const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
            const payload = {
              message: {
                token: token,
                notification: {
                  title: `${triggerType === 'LOW_BATTERY' ? '🔋 Low Battery SOS' : '🚨 EMERGENCY SOS'}`,
                  body: `${senderPhone} needs help! Tap to track.`
                },
                data: { 
                  sessionId: sessionId, 
                  id: sessionId,
                  session_id: sessionId,
                  type: 'SOS_ALERT' 
                },
                android: { 
                  priority: 'HIGH',
                  notification: {
                    channel_id: 'sos_push_alerts',
                    notification_priority: 'PRIORITY_MAX',
                    default_sound: true,
                    default_vibrate_timings: true
                  }
                }
              }
            };

            const response = await fetch(url, {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json'
              },
              body: JSON.stringify(payload)
            });
            console.log(`🚀 FCM Response for ${rawPhone}: ${response.status}`);
            if (!response.ok) {
              const errText = await response.text();
              console.error(`❌ FCM Error for ${rawPhone}: ${errText}`);
            }
          }
        } else {
          console.log(`ℹ️ No contact registered for ${rawPhone}`);
        }
      } catch (e) {
        console.error(`❌ Process error for ${rawPhone}: ${e.message}`);
      }
    }
  }

  return { statusCode: 200, body: 'SOS Processed' };
};

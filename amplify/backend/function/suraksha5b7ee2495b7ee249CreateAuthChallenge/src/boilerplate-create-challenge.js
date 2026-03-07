const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');

/**
 * Create Auth Challenge Lambda - OTP Generation & SMS
 * Generates a random 6-digit OTP and sends it via AWS SNS.
 * @type {import('@types/aws-lambda').CreateAuthChallengeTriggerHandler}
 */
exports.handler = async (event) => {
  console.log('CreateAuthChallenge event:', JSON.stringify(event, null, 2));

  try {
    let otp = null;
    const { session } = event.request;
    const phoneNumber = event.request.userAttributes ? event.request.userAttributes.phone_number : null;

    if (!phoneNumber) {
      console.error("[ERROR] No phone number found in userAttributes!");
      return event;
    }

    const REGION = process.env.REGION;

    if (event.request.challengeName === 'CUSTOM_CHALLENGE') {

      // Check if this is a retry (session has history) or a new attempt
      if (session && session.length > 0) {
        // RETRY: Reuse existing OTP, DO NOT send SMS
        const previousChallengeMetadata = session.slice(-1)[0].challengeMetadata;

        if (previousChallengeMetadata) {
          const match = previousChallengeMetadata.match(/OTP-(\d+)/);
          if (match) {
            otp = match[1];
            console.log(`[DEBUG] RETRY detected. Reusing existing OTP: ${otp} for ${phoneNumber}`);
          }
        }
      }

      if (!otp) {
        // NEW SESSION: Generate new OTP and Send SMS
        otp = Math.floor(100000 + Math.random() * 900000).toString();
        console.log(`[DEBUG] Generated NEW OTP: ${otp}`);

        try {
          const snsClient = new SNSClient({ region: REGION });

          const command = new PublishCommand({
            PhoneNumber: phoneNumber,
            Message: `Your Suraksha+ verification code is: ${otp}`,
            MessageAttributes: {
              'AWS.SNS.SMS.SenderID': { DataType: 'String', StringValue: 'SURAKSHA' },
              'AWS.SNS.SMS.SMSType': { DataType: 'String', StringValue: 'Transactional' }
            }
          });

          await snsClient.send(command);
          console.log('[DEBUG] SMS sent successfully.');
        } catch (error) {
          console.error('[DEBUG] SNS SEND ERROR:', error);
        }
      }

      // Public params to hint client
      event.response.publicChallengeParameters = {
        phone: phoneNumber ? phoneNumber.slice(-4) : '****',
        debugOtp: otp // REMOVE IN PRODUCTION
      };

      // Private params for Verify step
      event.response.privateChallengeParameters = {
        answer: otp
      };

      event.response.challengeMetadata = `OTP-${otp}`;
    }
  } catch (error) {
    console.error('[DEBUG] CRITICAL LAMBDA ERROR:', error);
  }

  return event;
};

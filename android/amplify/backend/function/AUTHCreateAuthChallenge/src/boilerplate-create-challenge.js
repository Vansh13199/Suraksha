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
    const phoneNumber = event.request.userAttributes.phone_number;

    // Hardcode region to Osaka (ap-northeast-3)
    const REGION = 'ap-northeast-3';

    console.log(`[DEBUG] Handling CreateAuthChallenge for ${phoneNumber} in region ${REGION}`);

    if (event.request.challengeName === 'CUSTOM_CHALLENGE') {

      // Check if this is a retry (session has history) or a new attempt
      if (session && session.length > 0) {
        // RETRY: Reuse existing OTP, DO NOT send SMS
        const previousChallengeMetadata = session.slice(-1)[0].challengeMetadata;
        console.log('[DEBUG] Previous Metadata:', previousChallengeMetadata);

        if (previousChallengeMetadata) {
          // Format is "OTP-123456"
          const match = previousChallengeMetadata.match(/OTP-(\d+)/);
          if (match) {
            otp = match[1];
            console.log(`[DEBUG] RETRY detected. Reusing existing OTP: ${otp} for ${phoneNumber}`);
          }
        }
      }

      if (!otp) {
        // NEW SESSION or REUSE FAILED: Generate new OTP and Send SMS
        otp = Math.floor(100000 + Math.random() * 900000).toString();
        console.log(`[DEBUG] Generated NEW OTP: ${otp}`);

        // Send SMS via AWS SNS
        try {
          console.log('[DEBUG] Initializing SNS Client...');
          const snsClient = new SNSClient({ region: REGION });

          const command = new PublishCommand({
            PhoneNumber: phoneNumber,
            Message: `Your Suraksha+ verification code is: ${otp}`,
            MessageAttributes: {
              'AWS.SNS.SMS.SenderID': { DataType: 'String', StringValue: 'SURAKSHA' },
              'AWS.SNS.SMS.SMSType': { DataType: 'String', StringValue: 'Transactional' }
            }
          });
          console.log('[DEBUG] Sending SNS Publish Command...');
          const result = await snsClient.send(command);
          console.log('[DEBUG] SMS sent successfully. MessageId:', result.MessageId);
        } catch (error) {
          console.error('[DEBUG] SNS SEND ERROR:', error);
          // Don't throw, let the challenge proceed even if SMS fails (so we can see logs)
        }
      }

      // Set challenge parameters
      event.response.publicChallengeParameters = {
        phone: phoneNumber ? phoneNumber.slice(-4) : '****'
      };

      // Private - the answer to verify against
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

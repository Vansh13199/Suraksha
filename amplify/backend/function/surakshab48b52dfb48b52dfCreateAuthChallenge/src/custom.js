const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');

// Get region from lambda environment variables, default to ap-south-1
const region = process.env.REGION || process.env.AWS_REGION || 'ap-south-1';
const snsClient = new SNSClient({ region: 'ap-south-1' });

/**
 * @type {import('@types/aws-lambda').CreateAuthChallengeTriggerHandler}
 */
exports.handler = async (event, context) => {
    let secretLoginCode;
    
    // Check if phone_number is provided
    if (!event.request.userAttributes || !event.request.userAttributes.phone_number) {
        throw new Error('User phone number missing');
    }

    // Determine if this is the first custom challenge or a retry
    const customChallengeSession = (event.request.session || []).find(s => s.challengeName === 'CUSTOM_CHALLENGE');

    if (!customChallengeSession) {
        // Generate a new 6-digit OTP
        secretLoginCode = Math.floor(100000 + Math.random() * 900000).toString();

        const phoneNumber = event.request.userAttributes.phone_number;

        // AWS SNS Publish Command
        const command = new PublishCommand({
            Message: `[Suraksha] Your login OTP is: ${secretLoginCode}`,
            PhoneNumber: phoneNumber,
        });

        try {
            await snsClient.send(command);
            console.log("OTP SMS sent to:", phoneNumber);
        } catch (err) {
            console.error("Failed to send OTP via SMS:", err);
            throw err; // Cognito will catch this
        }

    } else {
        // Re-use code from previous attempt to avoid sending a new SMS for retry
        try {
            const metadata = customChallengeSession.challengeMetadata || '';
            const match = metadata.match(/CODE-(\d*)/);
            secretLoginCode = match ? match[1] : Math.floor(100000 + Math.random() * 900000).toString();
        } catch (e) {
            secretLoginCode = Math.floor(100000 + Math.random() * 900000).toString();
        }
        console.log(`[DEBUG] Generated OTP: ${secretLoginCode} for ${event.request.userAttributes.phone_number}`);
    }

    event.response.publicChallengeParameters = {
        phone_number: event.request.userAttributes.phone_number,
        debugOtp: secretLoginCode,
    };

    // Private parameters are checked by VerifyAuthChallengeResponse
    event.response.privateChallengeParameters = {
        secretLoginCode,
    };

    // Metadata helps us retrieve it in the next attempt
    event.response.challengeMetadata = `CODE-${secretLoginCode}`;

    return event;
};

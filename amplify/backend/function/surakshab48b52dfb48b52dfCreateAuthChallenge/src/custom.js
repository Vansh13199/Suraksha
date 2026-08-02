const { SESClient, SendEmailCommand } = require('@aws-sdk/client-ses');

// Force SES client to use ap-south-1 where the custom domain is verified
const sesClient = new SESClient({ region: 'ap-south-1' });

// Verified SES sender email — update this to your verified domain email
const SENDER_EMAIL = process.env.SES_SENDER_EMAIL || 'mail-delivery@dev-vansh.in';

/**
 * @type {import('@types/aws-lambda').CreateAuthChallengeTriggerHandler}
 */
exports.handler = async (event, context) => {
    let secretLoginCode;

    // Check if email is provided
    if (!event.request.userAttributes || !event.request.userAttributes.email) {
        throw new Error('User email missing');
    }

    // Determine if this is the first custom challenge or a retry
    const customChallengeSession = (event.request.session || []).find(s => s.challengeName === 'CUSTOM_CHALLENGE');

    if (!customChallengeSession) {
        // Generate a new 6-digit OTP
        secretLoginCode = Math.floor(100000 + Math.random() * 900000).toString();

        const userEmail = event.request.userAttributes.email;

        // AWS SES Send Email Command
        const command = new SendEmailCommand({
            Source: SENDER_EMAIL,
            Destination: {
                ToAddresses: [userEmail],
            },
            Message: {
                Subject: {
                    Data: 'Suraksha+ - Your Login OTP',
                    Charset: 'UTF-8',
                },
                Body: {
                    Html: {
                        Data: `
                            <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
                                <h2 style="color: #1565C0; text-align: center;">Suraksha+</h2>
                                <p style="font-size: 16px; color: #333;">Your one-time verification code is:</p>
                                <div style="background: #f0f4ff; border-radius: 12px; padding: 20px; text-align: center; margin: 16px 0;">
                                    <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #1565C0;">${secretLoginCode}</span>
                                </div>
                                <p style="font-size: 14px; color: #666;">This code expires in 5 minutes. Do not share it with anyone.</p>
                                <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />
                                <p style="font-size: 12px; color: #999; text-align: center;">Suraksha+ — Connecting Safety</p>
                            </div>
                        `,
                        Charset: 'UTF-8',
                    },
                    Text: {
                        Data: `[Suraksha+] Your login OTP is: ${secretLoginCode}. Do not share this code.`,
                        Charset: 'UTF-8',
                    },
                },
            },
        });

        try {
            await sesClient.send(command);
            console.log("OTP email sent to:", userEmail);
        } catch (err) {
            console.error("Failed to send OTP via SES:", err);
            throw err; // Cognito will catch this
        }

    } else {
        // Re-use code from previous attempt to avoid sending a new email for retry
        try {
            const metadata = customChallengeSession.challengeMetadata || '';
            const match = metadata.match(/CODE-(\d*)/);
            secretLoginCode = match ? match[1] : Math.floor(100000 + Math.random() * 900000).toString();
        } catch (e) {
            secretLoginCode = Math.floor(100000 + Math.random() * 900000).toString();
        }
        console.log(`[DEBUG] Re-using OTP: ${secretLoginCode} for ${event.request.userAttributes.email}`);
    }

    event.response.publicChallengeParameters = {
        email: event.request.userAttributes.email,
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

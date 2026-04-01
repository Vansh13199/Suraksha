/**
 * @type {import('@types/aws-lambda').DefineAuthChallengeTriggerHandler}
 */
exports.handler = async (event, context) => {
    if (event.request.session.length === 0) {
        // If we don't have a session yet, start the flow
        // With SRP, this might be triggered after SRP is done
        event.response.issueTokens = false;
        event.response.failAuthentication = false;
        event.response.challengeName = 'CUSTOM_CHALLENGE';
    } else if (
        event.request.session.length === 1 &&
        event.request.session[0].challengeName === 'SRP_A' // Standard SRP started
    ) {
        event.response.issueTokens = false;
        event.response.failAuthentication = false;
        event.response.challengeName = 'CUSTOM_CHALLENGE';
    } else if (
        event.request.session.length > 0 &&
        event.request.session[event.request.session.length - 1].challengeName === 'CUSTOM_CHALLENGE' &&
        event.request.session[event.request.session.length - 1].challengeResult === true
    ) {
        // The user successfully answered the custom challenge (OTP)
        event.response.issueTokens = true;
        event.response.failAuthentication = false;
    } else {
        // Fallback for retries or failures
        if (event.request.session.length < 3) {
            event.response.issueTokens = false;
            event.response.failAuthentication = false;
            event.response.challengeName = 'CUSTOM_CHALLENGE';
        } else {
            event.response.issueTokens = false;
            event.response.failAuthentication = true;
        }
    }
    return event;
};

/**
 * Define Auth Challenge Lambda - Passwordless OTP Flow
 * Decides what challenge to present next.
 * @type {import('@types/aws-lambda').DefineAuthChallengeTriggerHandler}
 */
exports.handler = async (event) => {
  console.log('DefineAuthChallenge event:', JSON.stringify(event, null, 2));

  const { session } = event.request;

  // User not found
  if (event.request.userNotFound) {
    event.response.issueTokens = false;
    event.response.failAuthentication = true;
    return event;
  }

  // First attempt - no session, issue CUSTOM_CHALLENGE (OTP)
  if (session.length === 0) {
    event.response.issueTokens = false;
    event.response.failAuthentication = false;
    event.response.challengeName = 'CUSTOM_CHALLENGE';
    return event;
  }

  // Check the last challenge
  const lastChallenge = session[session.length - 1];

  console.log('[DEBUG] Last Challenge:', JSON.stringify(lastChallenge, null, 2));

  // OTP answered correctly - issue tokens
  if (lastChallenge.challengeName === 'CUSTOM_CHALLENGE' &&
    lastChallenge.challengeResult === true) {
    console.log('[DEBUG] Challenge successful, issuing tokens');
    event.response.issueTokens = true;
    event.response.failAuthentication = false;
    return event;
  }

  // Too many failed attempts (max 3)
  if (session.length >= 3 && lastChallenge.challengeResult === false) {
    console.log('[DEBUG] Too many failed attempts, failing authentication');
    event.response.issueTokens = false;
    event.response.failAuthentication = true;
    return event;
  }

  // Wrong OTP but still has attempts - issue another challenge
  console.log('[DEBUG] Challenge failed, issuing new challenge (retry)');
  event.response.issueTokens = false;
  event.response.failAuthentication = false;
  event.response.challengeName = 'CUSTOM_CHALLENGE';

  return event;
};

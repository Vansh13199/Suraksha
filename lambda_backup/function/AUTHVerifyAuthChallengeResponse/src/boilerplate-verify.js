/**
 * Verify Auth Challenge Response Lambda
 * Compares user's OTP input against the expected value.
 * @type {import('@types/aws-lambda').VerifyAuthChallengeResponseTriggerHandler}
 */
exports.handler = async (event) => {
  console.log('VerifyAuthChallenge event:', JSON.stringify(event, null, 2));

  const expectedAnswer = event.request.privateChallengeParameters.answer;
  const userAnswer = event.request.challengeAnswer;

  console.log(`[DEBUG] Expected: "${expectedAnswer}", User entered: "${userAnswer}"`);

  if (!expectedAnswer || !userAnswer) {
    console.log('[DEBUG] Missing expectedAnswer or userAnswer');
    event.response.answerCorrect = false;
    return event;
  }

  if (userAnswer === expectedAnswer || (typeof userAnswer === 'string' && typeof expectedAnswer === 'string' && userAnswer.trim() === expectedAnswer.trim())) {
    event.response.answerCorrect = true;
    console.log('[DEBUG] OTP verification SUCCESS');
  } else {
    event.response.answerCorrect = false;
    console.log('[DEBUG] OTP verification FAILED');
  }

  return event;
};

/**
 * @type {import('@types/aws-lambda').VerifyAuthChallengeResponseTriggerHandler}
 */
exports.handler = async (event, context) => {
    const challengeAnswer = event.request.challengeAnswer || '';
    const expectedAnswer = event.request.privateChallengeParameters.secretLoginCode || '';
    
    console.log(`[DEBUG] Comparing Answer: "${challengeAnswer}" with Expected: "${expectedAnswer}"`);

    // Robust comparison (String cast + Trim)
    if (String(challengeAnswer).trim() === String(expectedAnswer).trim()) {
        event.response.answerCorrect = true;
    } else {
        event.response.answerCorrect = false;
    }

    return event;
};

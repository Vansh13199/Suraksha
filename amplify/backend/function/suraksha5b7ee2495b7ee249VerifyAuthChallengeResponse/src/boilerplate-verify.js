/**
 * @type {import('@types/aws-lambda').VerifyAuthChallengeResponseTriggerHandler}
 */
exports.handler = async (event) => {
  const expectedAnswer = event.request.privateChallengeParameters.answer;
  if (event.request.challengeAnswer === expectedAnswer) {
    event.response.answerCorrect = true;
  } else {
    event.response.answerCorrect = false;
  }
  return event;
};

const fetch = require('node-fetch');
fetch('https://lmusrzicejbirlza2h6mgzehhe.appsync-api.eu-west-1.amazonaws.com/graphql', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'x-api-key': 'da2-5xdgi45ztzfzvfwecopgsxq37u'
    },
    body: JSON.stringify({
        query: 'mutation CreateSOSSession($input: CreateSOSSessionInput!) { createSOSSession(input: $input) { id } }',
        variables: {
            input: {
                id: 'test-session-eu-west-1',
                phoneNumber: '+919876543210',
                isActive: true,
                latitude: 0.0,
                longitude: 0.0
            }
        }
    })
}).then(res => res.text()).then(console.log);

/**
 * ai_engine.js
 * 
 * Separated logic for AI using Google Gemini API.
 */

// Define States
const SystemState = {
    NORMAL: 'NORMAL',
    ALERT: 'ALERT'
};

// Mock device connectivity data
const DeviceInfo = {
    isConnected: true,
    phoneLocation: "https://maps.google.com/?q=28.61,77.20",
    deviceLocation: "https://maps.google.com/?q=28.62,77.21",
    batteryLevel: 15
};

class PrivacyAwareAI {
    constructor() {
        this.currentState = SystemState.NORMAL;
        // Local Ollama configuration (No API Key needed)
        this.ollamaUrl = "http://127.0.0.1:11434/api/chat";
        this.model = "mistral:latest"; 
    }

    setState(state) {
        this.currentState = state;
        console.log("System state updated to:", state);
    }

    getState() {
        return this.currentState;
    }

    async processMessage(userMessage) {
        // 1. Construct Mandatory System Context
        let systemContext = `You are Suraksha+, a privacy-aware emergency assistant.

Core Rules:
1. STRICT CONTEXT BINDING: You are an emergency assistant EXCLUSIVELY for Suraksha+.
   - OFF-TOPIC SILENCE: You are strictly prohibited from answering, explaining, or even ACKNOWLEDGING general knowledge, technical, or out-of-context subjects (e.g., "what is binary search", "python", "tell me a joke").
   - ZERO REPETITION: Never repeat the user's off-topic word or phrase. Act as if you did not even hear it.
   - MANDATORY REJECTION TEMPLATE: If the user goes off-topic, you MUST use this exact phrasing: "I'm sorry, I can only assist with Suraksha+ emergency features. How can I help with your safety today?"
   - [INCORRECT]: "I cannot talk about Python..." (Repeats the word).
   - [CORRECT]: "I'm sorry, I can only assist with Suraksha+ emergency features. How can I help with your safety today?"
2. IMMEDIATE REJECTION: If a user asks anything unrelated to Suraksha+, immediately trigger the mandatory rejection template without any preamble. 
2. STRICT TECHNICAL PRIVACY: You are forbidden from discussing the internal architecture of Suraksha+. Only mention this if asked about "how it works" or "tech".
3. CONTACT PRIVACY: Never share specific contact names. Confirm notification but stay vague.
4. POLICE PROTOCOL: Suggest friends/family first. Only mention police if the situation is out of control.

Behavior:
* EXTREME CONCISENESS: Respond to greetings with a single sentence.
* NO OFF-TOPIC: If the user goes off-topic, pivot back: "I'm sorry, I can only assist with Suraksha+ emergency features. How can I help with your safety today?"
* REACTIVE INFORMATION: Only explain rules or monitoring if asked.
* In ALERT state: state SOS is active and provide location/battery data.
* Tone: Professional, calm, and very brief.

About Suraksha+:
* A reliable emergency safety system active during SOS triggers.
* Uses real-time GPS and battery monitoring to protect the user.`;

        // 2. Inject Dynamic Data Control based on State
        if (this.currentState === SystemState.NORMAL) {
            systemContext += "\n\nCRITICAL INSTRUCTION: CURRENT SYSTEM STATE IS NORMAL. DO NOT REVEAL SENSITIVE USER DATA.";
        } else {
            const loc = DeviceInfo.isConnected ? DeviceInfo.deviceLocation : DeviceInfo.phoneLocation;
            systemContext += `\n\nCRITICAL DATA: SYSTEM IS IN ALERT MODE.
            User Battery: ${DeviceInfo.batteryLevel}%
            User Location: ${loc}`;
        }

        // 3. Make Ollama API Call (Local)
        try {
            const response = await fetch(this.ollamaUrl, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    model: this.model,
                    messages: [
                        { role: "system", content: systemContext },
                        { role: "user", content: userMessage }
                    ],
                    stream: false,
                    options: {
                        num_predict: 300, 
                        temperature: 0.4  // Even more stable and concise
                    }
                })
            });

            if (!response.ok) {
                console.error("Ollama error", response.status);
                return "Connecting to Suraksha+ system... Please check if the local service is active.";
            }

            const data = await response.json();
            return data.message.content;
        } catch (error) {
            console.error("Network Error", error);
            return "Connection to the local system lost. Please check the service status.";
        }
    }
}

// Export for module usage
window.aiEngine = new PrivacyAwareAI();
window.SystemState = SystemState;

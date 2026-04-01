/**
 * script.js
 * 
 * UI interactions and integration with ai_engine.js
 * Separates DOM handling from business logic to ease future Flutter porting.
 */

document.addEventListener('DOMContentLoaded', () => {
    // UI Elements
    const fab = document.getElementById('ai-fab');
    const chatWindow = document.getElementById('chat-window');
    const aiAssistantContainer = document.getElementById('ai-assistant-container');
    const aiFab = document.getElementById('ai-fab');
    const closeChat = document.getElementById('close-chat');
    const sendBtn = document.getElementById('send-btn');
    const userInput = document.getElementById('user-input');
    const chatMessages = document.getElementById('chat-messages');
    
    const initTime = document.getElementById('init-time');

    // Demo Controls
    const triggerBatteryBtn = document.getElementById('trigger-battery');
    const triggerNormalBtn = document.getElementById('trigger-normal');

    // Initialize Time
    if (initTime) {
        initTime.textContent = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }
    
    // Toggle Chat visibility
    aiFab.addEventListener('click', () => {
        const isOpen = chatWindow.classList.toggle('hidden');
        if (!chatWindow.classList.contains('hidden')) {
            userInput.focus();
            aiAssistantContainer.classList.add('chat-open');
        } else {
            aiAssistantContainer.classList.remove('chat-open');
        }
    });

    closeChat.addEventListener('click', () => {
        chatWindow.classList.add('hidden');
        aiAssistantContainer.classList.remove('chat-open');
    });

    // Demo Control Events are now handled at the end of the script to avoid duplication and ensure correct state management.

    // Send Message Logic
    const sendMessage = async () => {
        const text = userInput.value.trim();
        if (!text) return;

        appendMessage('user', text);
        userInput.value = '';

        const typingId = Date.now();
        showTypingIndicator(typingId);

        // Get AI response (Local Ollama API)
        const response = await window.aiEngine.processMessage(text);
        
        // Always remove the typing indicator once the response is ready
        removeTypingIndicator(typingId);
        
        // Format and append the message
        const formattedHTML = response.replace(/\n(.*)/g, '<br>$1');
        appendMessage('ai', formattedHTML);
    };

    sendBtn.addEventListener('click', sendMessage);
    userInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            sendMessage();
        }
    });

    // Helpers
    function showTypingIndicator(id) {
        const msgDiv = document.createElement('div');
        msgDiv.className = 'message ai-message typing-indicator';
        msgDiv.id = id;
        msgDiv.innerHTML = '<p><em>AI is typing<span>.</span><span>.</span><span>.</span></em></p>';
        chatMessages.appendChild(msgDiv);
        scrollToBottom();
    }

    function removeTypingIndicator(id) {
        const indicator = document.getElementById(id);
        if (indicator) {
            indicator.remove();
        }
    }

    function appendMessage(sender, text) {
        const msgDiv = document.createElement('div');
        msgDiv.className = `message ${sender}-message`;
        
        const textP = document.createElement('p');
        textP.innerHTML = text; // Used innerHTML to allow API-generated HTML anchor links
        msgDiv.appendChild(textP);

        const timeSpan = document.createElement('span');
        timeSpan.className = 'timestamp';
        timeSpan.textContent = getFormattedTime();
        msgDiv.appendChild(timeSpan);

        chatMessages.appendChild(msgDiv);
        scrollToBottom();
    }

    function addSystemMessage(text) {
        const msgDiv = document.createElement('div');
        msgDiv.className = `message system-message`;
        msgDiv.textContent = text;
        chatMessages.appendChild(msgDiv);
        scrollToBottom();
    }

    function scrollToBottom() {
        chatMessages.scrollTop = chatMessages.scrollHeight;
    }

    function addNotificationEntry(title) {
        // Redirecting to Contact Chat entries
        appendContactMessage('ai', `🚨 <b>System Notification:</b> ${title}`);
    }

    function appendContactMessage(sender, text) {
        const msgList = document.getElementById('contact-messages');
        if (!msgList) return;

        const msgDiv = document.createElement('div');
        msgDiv.className = `message ${sender === 'user' ? 'user-message' : 'ai-message'}`;
        
        const textP = document.createElement('p');
        textP.innerHTML = text;
        msgDiv.appendChild(textP);

        const timeSpan = document.createElement('span');
        timeSpan.className = 'timestamp';
        timeSpan.textContent = getFormattedTime();
        msgDiv.appendChild(timeSpan);

        msgList.appendChild(msgDiv);
        msgList.scrollTop = msgList.scrollHeight;
    }

    function getFormattedTime() {
        const now = new Date();
        return now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    // --- BATTERY-BASED TRIGGER (SIMULATION) ---
    // Globally exposed to act as the requested function
    window.triggerLowBatteryAlert = function() {
        if(window.aiEngine.getState() === window.SystemState.ALERT) return; // Already in alert
        
        window.aiEngine.setState(window.SystemState.ALERT);
        updateUIMode();
        addSystemMessage("⚠️ Low battery detected. Emergency contacts notified.");
        
        // REQUIREMENT 1: Victim Message
        appendMessage('ai', "⚠️ Your battery is critically low. Your emergency contacts have been notified. Please stay reachable and contact someone nearby.");
        
        // REQUIREMENT 2: Notification Panel Update
        addNotificationEntry("Agastya → Battery Low Alert Sent");

        // Auto-open chat if hidden to ensure user sees the alert
        if (chatWindow.classList.contains('hidden')) {
            chatWindow.classList.remove('hidden');
            scrollToBottom();
        }
    };

    window.restoreNormalState = function() {
        if(window.aiEngine.getState() === window.SystemState.NORMAL) return;
        
        window.aiEngine.setState(window.SystemState.NORMAL);
        updateUIMode();
        addSystemMessage("✅ System restored to NORMAL state. Privacy locks engaged.");
    };

    // Update styling based on internal state
    function updateUIMode() {
        const state = window.aiEngine.getState();
        const isAlert = state === window.SystemState.ALERT;

        // Fab styling
        if (isAlert) fab.classList.add('alert-mode');
        else fab.classList.remove('alert-mode');

        // Send button styling
        if (isAlert) sendBtn.classList.add('alert-mode');
        else sendBtn.classList.remove('alert-mode');

        // Header styling has been removed as per the requirement: "no normal and alert things gonna be there"
    }

    // --- DUAL CHAT INITIALIZATION ---
    const contactChat = document.getElementById('contact-chat');
    const contactInput = document.getElementById('contact-input');
    const contactSendBtn = document.getElementById('contact-send-btn');

    // Handle Contact Input
    const sendContactMessage = async () => {
        const text = contactInput.value.trim();
        if (!text) return;

        appendContactMessage('user', text); // User here is the Emergency Contact
        contactInput.value = '';

        // Suraksha+ replies to contacts
        const response = await window.aiEngine.processMessage(`[Emergency Contact Interaction]: "${text}". (IMPORTANT: You are speaking to Agastya's emergency contacts, NOT to Agastya himself. Always refer to him in the third person using "he", "his", or "Agastya's".)`);
        setTimeout(() => {
            appendContactMessage('ai', response);
        }, 800);
    };

    if (contactSendBtn) contactSendBtn.addEventListener('click', sendContactMessage);
    if (contactInput) {
        contactInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') sendContactMessage();
        });
    }

    // Connect Demo Action Buttons
    if (triggerBatteryBtn) {
        triggerBatteryBtn.addEventListener('click', () => {
            window.triggerLowBatteryAlert();
        });
    }

    if (triggerNormalBtn) {
        triggerNormalBtn.addEventListener('click', () => {
            window.restoreNormalState();
        });
    }

    // Override Alert UI update to include Contact Chat visibility
    const originalUpdateUIMode = updateUIMode;
    updateUIMode = function() {
        originalUpdateUIMode();
        const state = window.aiEngine.getState();
        if (state === window.SystemState.ALERT) {
            contactChat.classList.remove('hidden');
            appendContactMessage('ai', "🚨 <b>EMERGENCY ALERT</b>: Agastya's device is critically low on battery. <br><a href='https://maps.google.com/?q=28.62,77.21' target='_blank' style='color: #007BFF; text-decoration: underline; font-weight: 600;'>📍 Check Live Location</a>");
        } else {
            contactChat.classList.add('hidden');
        }
    };
});

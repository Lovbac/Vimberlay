import { log } from "../../shared/utils.js";
import { sendCommand } from "../../shared/commands.js";
import { getCurrentState } from "../../shared/sse.js";
import { applyInputHighlight, updatePassthroughSignal } from "./actions.js";

// === MESSAGE HANDLING (From content scripts) ===

export function registerListeners() {
    registerMessageHandler();
    registerTabHandlers();
}

function registerMessageHandler() {
    chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
        if (message.type === "linkhints") {
            sendCommand({
                command: "linkhints",
                active: message.active,
                timestamp: Date.now()
            }).then(success => {
                log.debug("linkhints", message.active ? "ON" : "OFF", success ? "(sent)" : "(failed)");
                sendResponse({ success });
            });
            return true; // Keep channel open for async response
        } else if (message.type === "sid") {
            sendCommand({
                command: "sid",
                value: message.value,
                timestamp: Date.now()
            }).then(success => {
                log.debug("SID =", message.value, success ? "(sent)" : "(failed)");
                sendResponse({ success });
            });
            return true;
        } else if (message.type === "focusChanged") {
            // Re-apply highlighting when focus changes
            const state = getCurrentState();
            if (state) {
                applyInputHighlight(state);
            }
            return false;
        } else if (message.type === "inputClicked") {
            sendCommand({
                command: "input_clicked",
                timestamp: Date.now()
            });
            return false;
        } else if (message.type === "inputBlurred") {
            sendCommand({
                command: "input_blurred",
                timestamp: Date.now()
            });
            return false;
        }
    });
}

// === TAB ACTIVATION ===

function registerTabHandlers() {
    chrome.tabs.onActivated.addListener(async (activeInfo) => {
        try {
            // Directly read SID from sessionStorage - more reliable than messaging
            const results = await chrome.scripting.executeScript({
                target: { tabId: activeInfo.tabId },
                func: () => {
                    // NOTE: SID generation logic is duplicated from content-early.js because
                    // executeScript functions run in an isolated context with no access to imports.
                    const STORAGE_KEY = "vimaldi_tab_id";
                    const SID_MAX = 0xFFFFFF;
                    let sid = sessionStorage.getItem(STORAGE_KEY);
                    if (!sid) {
                        sid = Math.floor(Math.random() * SID_MAX).toString(16).toUpperCase().padStart(6, '0');
                        sessionStorage.setItem(STORAGE_KEY, sid);
                    }
                    return sid;
                }
            });

            if (results && results[0] && results[0].result) {
                const sid = results[0].result;
                sendCommand({
                    command: "sid",
                    value: sid,
                    timestamp: Date.now()
                });
                log.debug("SID =", sid, "(via executeScript)");
            }

            // Re-apply passthrough signal on tab switch
            const state = getCurrentState();
            if (state) {
                updatePassthroughSignal(state);
            }
        } catch (err) {
            // Can't inject into chrome://, about:, etc.
            log.debug("Can't read SID from tab", activeInfo.tabId, err.message);
        }
    });

    // === PAGE NAVIGATION DETECTION ===

    chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
        if (tab.active && changeInfo.status === 'loading') {
            sendCommand({
                command: "reset_to_normal",
                source: "tabs.onUpdated",
                url: tab.url,
                timestamp: Date.now()
            });
            log.debug("Page loading, reset to NORMAL");
        }
    });
}

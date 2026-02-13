import { log } from "../../shared/utils.js";
import { VimberlayMode, config } from "../../shared/config.js";
import { sendCommand } from "../../shared/commands.js";

// === ACTION EXECUTION ===

export async function executeAction(data) {
    switch (data.action) {
        case "blur":
            await performBlur();
            break;
        default:
            log.debug("Unknown action", data.action);
    }
}

async function performBlur() {
    try {
        const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
        if (!tabs[0]) return;

        await chrome.scripting.executeScript({
            target: { tabId: tabs[0].id },
            func: () => {
                if (document && document.body) {
                    const i = document.createElement('input');
                    i.style.cssText = 'position:fixed;opacity:0;pointer-events:none;top:-9999px';
                    document.body.appendChild(i);
                    i.focus();
                    i.blur();
                    i.remove();
                }
            }
        });
        log.debug("Blur executed");
        await sendCommand({ command: "blur_complete", timestamp: Date.now() });
    } catch (err) {
        // Can't inject into chrome://, about:, etc.
    }
}

// === INPUT HIGHLIGHTING (via executeScript) ===

export async function applyInputHighlight(state) {
    try {
        if (!config || !config.modeProperties) return;

        const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
        if (!tabs[0]) return;

        await chrome.scripting.executeScript({
            target: { tabId: tabs[0].id, allFrames: true },
            func: (state, modeProperties, VimberlayMode, debug) => {
                // Traverse shadow roots to find the actual focused element
                function getDeepActiveElement() {
                    let el = document.activeElement;
                    while (el && el.shadowRoot && el.shadowRoot.activeElement) {
                        el = el.shadowRoot.activeElement;
                    }
                    return el;
                }

                const el = getDeepActiveElement();
                const isInput = el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);

                let highlightColor = "";
                if (state.mode === VimberlayMode.INSERT) {
                    highlightColor = modeProperties[state.mode].backgroundColor;
                }

                // Clear old highlights (check shadow roots too)
                function clearHighlights(root) {
                    root.querySelectorAll('[data-vimberlay-highlight="true"]').forEach(e => {
                        if (e !== el || !highlightColor) {
                            e.style.removeProperty('background-color');
                            delete e.dataset.vimberlayHighlight;
                        }
                    });
                    // Also check shadow roots
                    root.querySelectorAll('*').forEach(e => {
                        if (e.shadowRoot) clearHighlights(e.shadowRoot);
                    });
                }
                clearHighlights(document);

                // Apply highlight
                if (highlightColor && isInput) {
                    el.style.setProperty('background-color', highlightColor, 'important');
                    if (!el.style.borderRadius) {
                        el.style.setProperty('border-radius', '5px', 'important');
                    }
                    el.dataset.vimberlayHighlight = "true";
                    if (debug) console.log("Vimberlay: Highlighted", el.tagName, el.className);
                }
            },
            args: [state, config.modeProperties, VimberlayMode, log.enabled]
        });
    } catch (err) {
        // Can't inject into chrome://, about:, etc.
    }
}

// === PASSTHROUGH SIGNAL (for SurfingKeys) ===

export async function updatePassthroughSignal(state) {
    try {
        const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
        if (!tabs[0]) return;

        await chrome.scripting.executeScript({
            target: { tabId: tabs[0].id },
            func: (isPassthrough) => {
                let signal = document.getElementById('vimberlay-signal');
                if (!signal) {
                    signal = document.createElement('div');
                    signal.id = 'vimberlay-signal';
                    signal.style.display = 'none';
                    document.documentElement.appendChild(signal);
                }
                signal.dataset.passthrough = isPassthrough ? 'true' : 'false';
            },
            args: [state.mode === VimberlayMode.PASSTHROUGH]
        });
    } catch (err) {
        // Can't inject into chrome://, about:, etc.
    }
}

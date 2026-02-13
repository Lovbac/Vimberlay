// ==============================================================================
// Vimberlay Content Script (runs at document_end)
// Handles Surfingkeys hints detection and focus change notifications
// ==============================================================================

(function () {
    "use strict";

    let lastHintsActive = false;
    let hintsHostObserver = null;
    let shadowObserver = null;

    const SHADOW_CHECK_INTERVAL_MS = 50;
    const SHADOW_CHECK_TIMEOUT_MS = 2000;
    const HINTS_RETRY_MAX = 20;
    const HINTS_RETRY_INTERVAL_MS = 500;

    // Safe wrapper for chrome.runtime.sendMessage
    function safeSendMessage(message) {
        try {
            chrome.runtime.sendMessage(message);
        } catch (err) {
            console.error("Vimberlay: Could not send to extension runtime (likely because extension context has been invalidated)", err, message);
        }
    }

    // --- HINTS DETECTION ---
    function checkHintsState(shadowRoot) {
        // SurfingKeys sets mode="click" on the section element for link hints.
        // For 'gi' (focus input), it uses mode="input", which we want to ignore.
        const active = !!shadowRoot.querySelector('section[mode="click"]');
        if (active !== lastHintsActive) {
            lastHintsActive = active;
            safeSendMessage({ type: "linkhints", active: active });
        }
    }

    function observeShadowRoot(shadowRoot) {
        if (shadowObserver) {
            shadowObserver.disconnect();
        }

        checkHintsState(shadowRoot);

        shadowObserver = new MutationObserver(() => {
            checkHintsState(shadowRoot);
        });

        shadowObserver.observe(shadowRoot, {
            childList: true,
            subtree: true
        });
    }

    function onHintsHostFound(hintsHost) {
        if (hintsHost.shadowRoot) {
            observeShadowRoot(hintsHost.shadowRoot);
        } else {
            const checkShadow = setInterval(() => {
                if (hintsHost.shadowRoot) {
                    clearInterval(checkShadow);
                    observeShadowRoot(hintsHost.shadowRoot);
                }
            }, SHADOW_CHECK_INTERVAL_MS);
            setTimeout(() => clearInterval(checkShadow), SHADOW_CHECK_TIMEOUT_MS);
        }
    }

    function findAndObserveHintsHost() {
        const hintsHost = document.querySelector('.surfingkeys_hints_host');
        if (hintsHost) {
            onHintsHostFound(hintsHost);
            return true;
        }
        return false;
    }

    function setupHintsObserver() {
        if (findAndObserveHintsHost()) {
            return;
        }

        hintsHostObserver = new MutationObserver((mutations) => {
            for (const mutation of mutations) {
                for (const node of mutation.addedNodes) {
                    if (node.nodeType === Node.ELEMENT_NODE) {
                        if (node.classList?.contains('surfingkeys_hints_host')) {
                            onHintsHostFound(node);
                            return;
                        }
                        const host = node.querySelector?.('.surfingkeys_hints_host');
                        if (host) {
                            onHintsHostFound(host);
                            return;
                        }
                    }
                }
            }
        });

        hintsHostObserver.observe(document.documentElement, {
            childList: true,
            subtree: true
        });
    }

    // --- INITIALIZATION ---
    setupHintsObserver();

    // Notify background on focus changes so it can re-apply highlighting
    document.addEventListener('focusin', () => {
        safeSendMessage({ type: "focusChanged" });
    });

    document.addEventListener('focusout', (e) => {
        const target = e.composedPath()[0] || e.target;
        if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable)) {
            if (document.hasFocus()) {
                safeSendMessage({ type: "inputBlurred" });
            }
        }
        safeSendMessage({ type: "focusChanged" });
    });

    // Notify background when an input/textarea is CLICKED
    document.addEventListener('click', (e) => {
        // Use composedPath to find the element even through Shadow DOM
        const target = e.composedPath()[0] || e.target;
        if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable)) {
            safeSendMessage({ type: "inputClicked" });
        }
    });

    // Re-check for Surfingkeys hints host periodically
    let retryCount = 0;
    const retryInterval = setInterval(() => {
        if (findAndObserveHintsHost() || ++retryCount > HINTS_RETRY_MAX) {
            clearInterval(retryInterval);
        }
    }, HINTS_RETRY_INTERVAL_MS);
})();

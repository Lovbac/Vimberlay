import { loadServerConfig, config } from "../shared/config.js";
import { log } from "../shared/utils.js";
import { registerListeners } from "./lib/listeners.js";
import { setupSse } from "../shared/sse.js";
import { applyInputHighlight, updatePassthroughSignal, executeAction } from "./lib/actions.js";

// Runs after SSE connection has been established and the initial state has been received.
// Don't run code before this point without reason.
function onInit() {
    registerListeners();
}

// Runs on every state update. If it's the initial state, it runs after onInit.
function onStateUpdate(state) {
    applyInputHighlight(state);
    updatePassthroughSignal(state);
}

// Promise-chaining is required because top-level await is disallowed in service workers.
loadServerConfig().then((loaded) => {
    if (loaded) {
        const didSetup = setupSse({
            onInit,
            onStateUpdate,
            onAction: executeAction,
            keepAliveMs: 25000,
        });
        if (!didSetup) {
            log.debug("SSE setup failed. Exiting.");
        }
    } else {
        log.debug("Server config was not loaded. Exiting.");
    }
});

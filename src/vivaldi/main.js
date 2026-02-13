import { loadServerConfig, config } from "../shared/config.js";
import { log } from "../shared/utils.js";
import { applyStyles, updateVisualState } from "./lib/visuals.js";
import { setupSse } from "../shared/sse.js";

// Runs after SSE connection has been established and the initial state has been received.
// Don't run code before this point without reason.
function onInit() {
    applyStyles();
}

// Runs on every state update. If it's the initial state it runs after onInit.
function onStateUpdate(state) {
    updateVisualState(state);
}

const loaded = await loadServerConfig();
if (loaded) {
    if (config.useVivaldiEnhancements) {
        const didSetup = setupSse({
            onInit,
            onStateUpdate
        });
        if (!didSetup) {
            log.debug("SSE setup failed. Exiting.");
        }
    } else {
        log.debug("Vivaldi enhancements are disabled. Exiting.");
    }
} else {
    log.debug("Server config was not loaded. Exiting.");
}

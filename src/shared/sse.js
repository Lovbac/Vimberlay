import { AHK_URL } from "./config.js";
import { log } from "./utils.js"

let eventSource = null;
let initialized = false;
let currentState = null;

export function getCurrentState() { return currentState; }

export function setupSse({ onInit, onStateUpdate, onAction, keepAliveMs }) {
    try {
        eventSource = new EventSource(AHK_URL + "/events");
    } catch (err) {
        log.debug("Failed to create EventSource", err);
        return false;
    }

    eventSource.onopen = () => {
        log.debug("SSE connection established with AHK");
    };

    eventSource.addEventListener("state", (event) => {
        try {
            currentState = JSON.parse(event.data);
            log.debug("Received state update", currentState);

            if (!initialized) {
                initialized = true;
                log.debug("State initialized");
                onInit?.();
                if (keepAliveMs) startKeepAlive(keepAliveMs);
            }

            onStateUpdate?.(currentState);
        } catch (err) {
            log.debug("Error when handling SSE state update", err, event.data);
        }
    });

    if (onAction) {
        eventSource.addEventListener("action", (event) => {
            try {
                const data = JSON.parse(event.data);
                log.debug("Action received", data);
                onAction(data);
            } catch (err) {
                log.debug("Error when handling SSE action", err, event.data);
            }
        });
    }

    eventSource.onerror = (err) => {
        log.debug("SSE connection error. EventSource will attempt auto-reconnects.", err);
    };

    return true;
}

// === KEEPALIVE FOR MV3 SERVICE WORKER ===

function startKeepAlive(intervalMs) {
    setInterval(() => {
        if (eventSource && eventSource.readyState === EventSource.OPEN) {
            log.debug("Sse keep-alive ping", eventSource.readyState);
        }
    }, intervalMs);
}

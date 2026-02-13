import { log } from "./utils.js"

export let AHK_URL = "http://127.0.0.1:8000";

export let VimberlayMode = null // Mode constants as defined in Config.ahk
export let config = null;

async function resolveUrl() {
    // 1. Check for global injected by VivaldiModPatcher
    if (typeof window !== "undefined" && window.__VIMBERLAY_URL) {
        return window.__VIMBERLAY_URL;
    }

    // 2. Check chrome.storage.local (extension popup)
    if (typeof chrome !== "undefined" && chrome.storage?.local) {
        try {
            const result = await chrome.storage.local.get("serverUrl");
            if (result.serverUrl) {
                return result.serverUrl;
            }
        } catch (err) {
            log.debug("Could not read serverUrl from chrome.storage", err);
        }
    }

    // 3. Default
    return "http://127.0.0.1:8000";
}

export async function loadServerConfig() {
    AHK_URL = await resolveUrl();

    let data = undefined;
    try {
        const res = await fetch(AHK_URL + "/config");
        if (res.ok) {
            data = await res.json();
            VimberlayMode = data.constants.vimberlayMode;
            config = data.config;
            log.enabled = !!config.debug;
            log.debug("Got server config", data);
            return true;
        }
        const errMsg = await res.text()
        log.debug("Failed to get server config", res.status, errMsg);
    } catch (err) {
        log.debug("Error when getting server config", err, ...(data !== undefined ? [data] : []));
    }
    return false;
}

import { AHK_URL } from "./config.js";
import { log } from "./utils.js";

export async function sendCommand(command) {
    try {
        const response = await fetch(AHK_URL + "/command", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(command)
        });
        if (response.ok) {
            log.debug("Sent command to server", command)
        } else {
            log.debug("Failed to send command to server", response.status, command)
        }
    } catch (err) {
        log.debug("Failed to send command", err);
        return false;
    }
}

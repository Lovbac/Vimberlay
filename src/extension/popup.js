const serverUrlInput = document.getElementById("server-url");
const statusEl = document.getElementById("status");

function showStatus(message, isError = false) {
    statusEl.textContent = message;
    statusEl.className = "item active " + (isError ? "error" : "success");
    setTimeout(() => {
        statusEl.className = "item";
        statusEl.textContent = "";
    }, 3000);
}

// Load current URL
chrome.storage.local.get("serverUrl", (result) => {
    serverUrlInput.value = result.serverUrl || "http://127.0.0.1:8000";
});

// Save server URL on blur or Enter
function saveUrl() {
    const url = serverUrlInput.value.trim();
    if (!url) {
        showStatus("URL cannot be empty", true);
        return;
    }

    try {
        new URL(url); // Validate URL format
        chrome.storage.local.set({ serverUrl: url }, () => {
            showStatus("Server URL saved");
        });
    } catch (err) {
        showStatus("Invalid URL format", true);
    }
}

serverUrlInput.addEventListener("keypress", (e) => {
    if (e.key === "Enter") {
        saveUrl();
    }
});

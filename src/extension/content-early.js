// ==============================================================================
// Vimberlay Early Content Script (runs at document_start)
// Initializes SID as early as possible - only needs sessionStorage
// ==============================================================================

(function () {
    "use strict";

    const STORAGE_KEY = "vimaldi_tab_id";

    let sid = sessionStorage.getItem(STORAGE_KEY);
    if (!sid) {
        const SID_MAX = 0xFFFFFF;
        sid = Math.floor(Math.random() * SID_MAX).toString(16).toUpperCase().padStart(6, '0');
        sessionStorage.setItem(STORAGE_KEY, sid);
    }

    // Send SID to background immediately
    chrome.runtime.sendMessage({ type: "sid", value: sid });
})();

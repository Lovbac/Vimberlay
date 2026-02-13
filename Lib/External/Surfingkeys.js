// ==============================================================================
// SURFINGKEYS CONFIG - VIMBERLAY INTEGRATION
// Dynamically disables/enables based on Vimberlay passthrough state
// ==============================================================================

function registerMappings() {
    // Clear all default mappings except gi and Esc
    api.unmapAllExcept(["gi", "<Esc>"], /./);

    // Ctrl-2 as alias for gi (focus first input)
    api.map("<Ctrl-2>", "gi");
    api.imapkey("<Ctrl-2>", "null", function () { });

    // --- LINK HINTS ---
    api.mapkey('<Ctrl-F>', 'Open Link Hints', () => {
        api.Hints.create("", api.Hints.dispatchMouseClick);
    });

    api.imapkey('<Ctrl-F>', 'Open Link Hints', () => {
        api.Hints.create("", api.Hints.dispatchMouseClick);
    });

    api.mapkey('<Alt-G>', 'Open Link Hints (New Tab Bg)', () => {
        api.Hints.create("", api.Hints.dispatchMouseClick, { tabbed: true, active: false });
    });

    api.imapkey('<Alt-G>', 'Open Link Hints (New Tab Bg)', () => {
        api.Hints.create("", api.Hints.dispatchMouseClick, { tabbed: true, active: false });
    });

    // --- NEOVIM INTEGRATION ---
    api.mapkey('<Alt-E>', 'Edit in Neovim', () => {
        // Placeholder - AHK handles the actual Neovim integration
    });

    api.imapkey('<Alt-E>', 'Edit in Neovim', () => {
        // Placeholder - AHK handles the actual Neovim integration
    });
}

function disableMappings() {
    // Exit any active SurfingKeys mode first (hints, omnibar, etc.)
    // Esc will be preserved by unmapAllExcept
    const escEvent = new KeyboardEvent('keydown', {
        key: 'Escape',
        code: 'Escape',
        keyCode: 27,
        which: 27,
        bubbles: true,
        cancelable: true
    });
    document.dispatchEvent(escEvent);

    // Small delay to let Esc take effect before unmapping
    setTimeout(() => {
        // Nuke all mappings except Esc (needed for page functionality)
        api.unmapAllExcept(["<Esc>"], /./);
    }, 50);
}

// --- PASSTHROUGH OBSERVER ---
// Watch for Vimberlay extenstion passthrough signal and toggle mappings accordingly

const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
        if (mutation.type === 'attributes' && mutation.attributeName === 'data-passthrough') {
            const signal = mutation.target;
            const isPassthrough = signal.dataset.passthrough === 'true';

            if (isPassthrough) {
                disableMappings();
                console.log('SurfingKeys: DISABLED (passthrough mode)');
            } else {
                registerMappings();
                console.log('SurfingKeys: ENABLED');
            }
        }
    }
});

// Wait for signal div to exist, then observe it
function watchForSignal() {
    const signal = document.getElementById('vimberlay-signal');
    if (signal) {
        observer.observe(signal, { attributes: true });
        // Check initial state
        if (signal.dataset.passthrough === 'true') {
            disableMappings();
        }
    } else {
        // Signal div not yet injected, check again soon
        setTimeout(watchForSignal, 100);
    }
}

// --- INITIALIZATION ---
registerMappings();
watchForSignal();

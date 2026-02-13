import { config } from "../../shared/config.js";

let modeTextContainer = null
let modeTextElem = null
let modeTextPersisterStarted = false;

export function applyStyles() {
    if (document.getElementById("vimberlay-address-styles"))
        throw new Error("Vimberlay styles already applied");

    const style = document.createElement('style');
    style.id = "vimberlay-address-styles";
    style.textContent = `
        :root {
            --vimberlay-address-bg: var(--colorBgIntense);
            --vimberlay-address-fg: var(--colorFg);
        }
        .UrlBar-AddressField {
            background-color: var(--vimberlay-address-bg) !important;
            outline: none !important;
        }
        .UrlField {
            background-color: var(--vimberlay-address-bg) !important;
        }
        .toolbar-insideinput {
            background-color: var(--vimberlay-address-bg) !important;
            padding: 3px !important;
            border-radius: 0 !important;
        }
        .toolbar-insideinput:first-of-type {
            border-radius: 8px 0 0 8px !important;
        }
        .toolbar-insideinput:last-of-type {
            border-radius: 0 8px 8px 0 !important;
        }
        .ModeText {
            font-family: monospace !important;
            margin-right: 5px !important;
            font-size: 13px !important;;
            height: 22px !important;
            line-height: 22px !important;
        }
    `;
    document.head.appendChild(style);
}

export function updateVisualState(state) {
    updateModeColor(state);
    updateModeText(state);
}

function updateModeColor(state) {
    const root = document.documentElement;
    if (config.modeProperties[state.mode].backgroundColor) {
        root.style.setProperty('--vimberlay-address-bg', config.modeProperties[state.mode].backgroundColor);
    }
    if (config.modeProperties[state.mode].foregroundColor) {
        root.style.setProperty('--vimberlay-address-fg', config.modeProperties[state.mode].foregroundColor);
    }
}

function updateModeText(state) {
    if (!modeTextContainer) {
        // Gets the containers for elements inside the urlbar
        const urlbarInsideElemContainers = document.querySelectorAll('.toolbar-insideinput');
        if (urlbarInsideElemContainers.length === 0) return;
        // The last container is the one containing the rightmost elements (e.g. bookmark button),
        // which is where the mode text will be appended.
        modeTextContainer = urlbarInsideElemContainers[urlbarInsideElemContainers.length - 1];
    }

    modeTextElem ||= modeTextContainer.querySelector('.ModeText');
    if (!modeTextElem) {
        modeTextElem = document.createElement('div');
        modeTextElem.className = 'ModeText';
        modeTextContainer.appendChild(modeTextElem);
    }

    modeTextElem.textContent = config.modeProperties[state.mode].text;

    // The browser sometimes rearranges the elements inside the urlbar,
    // so to persist the mode text as the rightmost element we observe
    // the container's contents and push the mode text back on changes.
    if (!modeTextPersisterStarted) {
        (new MutationObserver(() => {
            if (modeTextElem.nextSibling) {
                modeTextContainer.appendChild(modeTextElem);
            }
        })).observe(modeTextContainer, { childList: true });

        modeTextPersisterStarted = true;
    }
}

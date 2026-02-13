# Vimberlay

**Vim-like keybindings for your browser, powered by AutoHotkey.**

Vimberlay is a hybrid system that pairs an AutoHotkey v2 script with a Chromium browser extension to give you deep Vim-style navigation in Vivaldi, Chrome, or Edge. AHK handles system-level input and window management; the extension handles DOM-level interactions. They communicate over a local HTTP/SSE server running on `localhost`.

> [!NOTE]
> This project is in **alpha**. Things work, but expect rough edges, undocumented config options, and the occasional desync. If the mode indicator gets stuck, press `Esc` or `Shift+Esc` to reset.

---

## Features

- **Modal editing** — Normal, Insert, Hints, Passthrough, and Scrollmark modes with a visual mode indicator
- **Vim-style navigation** — `j`/`k` scrolling, `gg`/`G` jump to top/bottom, `H`/`L` history, `Ctrl+d`/`Ctrl+u` page scroll
- **Link hints** — Press `f` to label clickable elements and jump to them (via SurfingKeys integration)
- **External editor** — `Ctrl+e` opens the current input field (or address bar) in Neovim, with `:w`/`:wq`/`:cq` controlling what happens on return
- **Scroll markers** — Save positions on the page (`s` to select, `S` to set), jump to them by number, and navigate back through history
- **Tab management** — `J`/`K` to switch tabs, `X` to close, `U` to reopen, `b` to focus address bar
- **Vivaldi enhancements** — Optional UI patching that injects mode indicators directly into Vivaldi's toolbar
- **Configurable** — All keybindings and settings live in `UserConfig.ahk`; override anything from `Config.ahk`

---

## Prerequisites

| Requirement | Details |
|---|---|
| **OS** | Windows |
| **AutoHotkey** | v2.0+ |
| **Node.js** | For building the extension (esbuild) |
| **Browser** | Vivaldi (recommended), Chrome, or Edge |
| **SurfingKeys** | Browser extension — required for link hints (`f`) and `gi` (focus input) |

---

## Setup

### 1. Clone & install

```powershell
git clone https://github.com/Lovbac/Vimberlay.private.git
cd Vimberlay.private
npm install
```

### 2. Build the extension

```powershell
npm run build        # production build (minified, no sourcemaps)
npm run dev          # dev build (sourcemaps, no minification)
npm run watch        # rebuild on file changes
```

Output goes to `dist/extension/` (browser extension) and `dist/vivaldi/` (Vivaldi mod).

### 3. Load the extension

1. Open `chrome://extensions` (or `vivaldi://extensions`)
2. Enable **Developer Mode**
3. Click **Load Unpacked** → select the `dist/extension` folder

### 4. Configure AHK

Edit `UserConfig.ahk` in the project root:

```autohotkey
; Required — set your browser executable
Config.BrowserExecutable := "vivaldi.exe"

; Required — map your browser's keyboard shortcuts so Vimberlay can trigger them
Config.BrowserBindings.Reload := "^+!#2"
Config.BrowserBindings.HistoryBack := "^+!#1"
; ... see UserConfig.ahk for the full list
```

> [!TIP]
> The browser bindings are obscure key combos (like `Ctrl+Shift+Alt+Win+2`) that you assign in your browser's shortcut settings. Vimberlay sends these programmatically so they don't collide with your Vim keys.

### 5. Run

Double-click `VimValdi.ahk`. A tooltip will confirm the web server started on port `8000`.

---

## Keybindings

### Normal Mode

| Key | Action |
|---|---|
| `j` / `k` | Scroll down / up |
| `Ctrl+d` / `Ctrl+u` | Page down / up |
| `gg` | Scroll to top |
| `G` | Scroll to bottom |
| `f` / `F` | Link hints (current tab / new background tab) |
| `i` | Enter Insert mode |
| `I` / `A` | Insert at start / end of input |
| `o` | Open URL (address bar) |
| `O` | New tab |
| `Alt+o` | Edit current URL |
| `b` | Focus address bar |
| `J` / `K` | Next / previous tab |
| `X` | Close tab |
| `U` | Reopen closed tab |
| `r` / `R` | Reload / hard reload |
| `H` / `L` | History back / forward |
| `n` | Open DevTools |
| `Ctrl+e` | Edit input in Neovim |
| `s` / `S` | Scroll markers: select / set mode |
| `gi` | Focus first input field |

### Insert Mode

| Key | Action |
|---|---|
| `Esc` | Exit to Normal |
| `Ctrl+e` | Edit in Neovim |
| `Ctrl+Enter` | Submit and exit |

### Scroll Markers

| Key (Select mode) | Action |
|---|---|
| `1`–`9` | Jump to mark |
| `s` | Jump back (history) |
| `Esc` | Exit |

| Key (Editor mode) | Action |
|---|---|
| `h`/`j`/`k`/`l` | Move crosshair |
| `1`–`9` | Save mark at crosshair |
| `Shift+1`–`9` | Delete mark |
| `Shift+0` | Delete all marks |
| `Esc` | Exit |

### Global

| Key | Action |
|---|---|
| `Shift+Esc` | Toggle Passthrough (disables all Vimberlay keys) |
| `Ctrl+F11` | Toggle fullscreen |
| `Ctrl+o` | Refocus page |
| `Ctrl+=` / `Ctrl+-` / `Ctrl+0` | Zoom in / out / reset |

---

## Architecture

```
┌──────────────────────────────────────────────┐
│                 VimValdi.ahk                 │
│          (main entry, key mappings)          │
├──────────────────────────────────────────────┤
│  Lib/                                        │
│  ├── Core.ahk          State machine & loop  │
│  ├── Actions.ahk       All mapped actions    │
│  ├── WebServer.ahk     HTTP + SSE server     │
│  ├── ScrollMarker.ahk  Marks & visuals       │
│  ├── Config.ahk        Defaults & theming    │
│  ├── State.ahk         Shared state object   │
│  ├── Input.ahk         Input handling        │
│  ├── Visuals.ahk       GUI indicator drawing │
│  ├── Constants.ahk     Mode/action constants │
│  └── VivaldiModPatcher Vivaldi UI injection  │
└────────────┬─────────────────────────────────┘
             │  HTTP / SSE (localhost:8000)
             ▼
┌──────────────────────────────────────────────┐
│           Browser Extension (MV3)            │
│  ├── background.js     Service worker, SSE   │
│  ├── content.js        Hints & focus events  │
│  ├── content-early.js  Early DOM setup       │
│  └── shared/           SSE, config, utils    │
└──────────────────────────────────────────────┘
```

**How it works:**

1. AHK runs a Winsock-based HTTP server (`WebServer.ahk`) that serves config and exposes an SSE `/events` endpoint.
2. The browser extension's service worker connects to SSE and receives real-time state updates (current mode, active marks, etc.).
3. Content scripts detect SurfingKeys hint state and input focus changes, sending commands back to AHK via HTTP POST.
4. AHK's state machine (`Core.ahk`) runs on a 20ms timer, computing the current mode from window focus, typing detection, and extension feedback.

---

## Project Structure

```
VimBrowserOverlay/
├── VimValdi.ahk          # Entry point — run this
├── UserConfig.ahk        # Your personal config (gitignored ideally)
├── Lib/                  # AHK modules
├── src/
│   ├── extension/        # Browser extension source
│   ├── shared/           # JS shared between extension & Vivaldi mod
│   └── vivaldi/          # Vivaldi-specific UI mod
├── dist/                 # Built output (load this in your browser)
├── build.js              # esbuild build script
├── watch.js              # File watcher for dev
└── package.json
```

---

## Debugging

- **`web_log.txt`** — WebServer request log
- **`error_log.txt`** — AHK error log
- **Browser DevTools** → Extensions → Vimberlay service worker console for JS-side logs
- Set `Config.Debug := true` in `UserConfig.ahk` for verbose JS logging

---

## License

GPLv3
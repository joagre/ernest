// What the script adds to a page: the shell panel and its two buttons,
// beside and below, with its session over the server's WebSocket, a code
// block's Copy and Paste, a transcript's Paste for each input, its prompt
// the control, and the example's Try it. The page reads whole without it.

const icons = new URL("../img/icons.svg", document.currentScript.src);

function icon(name) {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("class", "icon");
  svg.setAttribute("aria-hidden", "true");
  const use = document.createElementNS("http://www.w3.org/2000/svg", "use");
  use.setAttribute("href", icons + "#" + name);
  svg.append(use);
  return svg;
}

function iconButton(name, label, className, action) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = className;
  button.title = label;
  button.setAttribute("aria-label", label);
  button.append(icon(name));
  button.addEventListener("click", action);
  return button;
}

function copy(text) {
  navigator.clipboard.writeText(text);
}

// The panel's layout and sizes are the visitor's, kept in the browser,
// and the page works without them: storage may be missing or refused.
function remembered(key, fallback) {
  try {
    return localStorage.getItem(key) ?? fallback;
  } catch {
    return fallback;
  }
}

function remember(key, value) {
  try {
    localStorage.setItem(key, value);
  } catch {
    // Not kept; the next page opens as the default.
  }
}

// Beside needs a wide window; on a narrower one the panel goes below, and
// on a phone there is none: the shell is its own page.
const wide = window.matchMedia("(min-width: 1000px)");
const phone = window.matchMedia("(max-width: 760px)");

const panel = {
  layout: null,
  element: null,
  terminal: null,
  state: null,
  buttons: {},
  running: false,
  onPage: false,
  opener: null,
};

function layoutFor(wanted) {
  return wanted === "beside" && !wide.matches ? "below" : wanted;
}

function showLayout(layout) {
  document.body.classList.toggle("panel-beside", layout === "beside");
  document.body.classList.toggle("panel-below", layout === "below");
  for (const [name, button] of Object.entries(panel.buttons)) {
    button.setAttribute("aria-pressed", String(name === layout));
  }
  panel.element.hidden = layout === null;
  panel.layout = layout;
  if (layout !== null) {
    panel.hide.replaceChildren(icon(layout === "beside" ? "panel-right" : "panel-bottom"));
  }
  showWaiting();
}

// A session that runs while the panel is hidden marks the button that
// brings it back.
function showWaiting() {
  const waiting = panel.running && panel.layout === null;
  const last = remembered("ernest.panel", "beside");
  for (const [name, button] of Object.entries(panel.buttons)) {
    button.classList.toggle("waiting", waiting && name === layoutFor(last));
  }
}

function openPanel(wanted) {
  const layout = layoutFor(wanted);
  panel.opener = document.activeElement;
  showLayout(layout);
  remember("ernest.panel", layout);
  remember("ernest.panel.open", "yes");
  focusTerminal();
}

function closePanel() {
  showLayout(null);
  remember("ernest.panel.open", "no");
  panel.opener?.focus?.();
}

function toggle(layout) {
  if (panel.layout === layout) {
    closePanel();
  } else {
    openPanel(layout);
  }
}

// The session: xterm.js over the server's WebSocket, as ernest-httpd's
// design §11 has it. The terminal's bytes go each way as binary messages;
// the page's own messages are text, one JSON object each: the terminal's
// size at the open and at each change, which attaches the session, an
// extend and a stop. The server's one text message is the warning of the
// seconds left, and its close code says why a session ended. xterm.js is
// loaded only when a session starts, so that a page read without the
// shell fetches none of it.
const here = document.currentScript.src;
const shellPath = "/shell/session"; // the server's shell.path, which the generator will write
const endings = {
  4001: "expired",
  4002: "taken over by another tab",
  4003: "unavailable",
  4004: "stopped",
};
const encoder = new TextEncoder();
const session = { socket: null, terminal: null, fit: null, pastes: [], restarting: false };

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = src;
    script.onload = resolve;
    script.onerror = reject;
    document.head.append(script);
  });
}

let xtermLoaded = null;

function loadXterm() {
  if (xtermLoaded === null) {
    const style = document.createElement("link");
    style.rel = "stylesheet";
    style.href = new URL("../css/xterm.css", here);
    document.head.append(style);
    xtermLoaded = loadScript(new URL("xterm.js", here))
      .then(() => loadScript(new URL("addon-fit.js", here)));
  }
  return xtermLoaded;
}

function token(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

async function startSession() {
  await loadXterm();
  if (session.terminal === null) {
    panel.terminal.replaceChildren();
    const terminal = new Terminal({
      screenReaderMode: true,
      macOptionIsMeta: true,
      fontFamily: token("--mono"),
      fontSize: 14,
      theme: { background: token("--terminal"), foreground: token("--terminal-ink") },
    });
    const fit = new FitAddon.FitAddon();
    terminal.loadAddon(fit);
    terminal.open(panel.terminal);
    terminal.onData((data) => sendKeys(encoder.encode(data)));
    terminal.onBinary((data) => sendKeys(Uint8Array.from(data, (char) => char.charCodeAt(0))));
    terminal.onResize((size) => sendText({ resize: [size.rows, size.cols] }));
    new ResizeObserver(() => {
      if (!panel.element.hidden) {
        fit.fit();
      }
    }).observe(panel.terminal);
    Object.assign(session, { terminal, fit });
  }
  session.fit.fit();
  connect();
}

function connect() {
  const scheme = location.protocol === "https:" ? "wss://" : "ws://";
  const socket = new WebSocket(scheme + location.host + shellPath);
  socket.binaryType = "arraybuffer";
  session.socket = socket;
  setState("connecting");
  socket.onopen = () => {
    session.terminal.reset();
    sendText({ resize: [session.terminal.rows, session.terminal.cols] });
    setState("running");
    focusTerminal();
  };
  socket.onmessage = (event) => {
    if (event.data instanceof ArrayBuffer) {
      session.terminal.write(new Uint8Array(event.data), pasteWaiting);
    } else {
      const message = JSON.parse(event.data);
      if ("warning" in message) {
        warn(message.warning);
      }
    }
  };
  socket.onclose = (event) => {
    if (socket !== session.socket) {
      return;
    }
    panel.warning.hidden = true;
    setState(endings[event.code] ?? "disconnected");
    if (session.restarting) {
      session.restarting = false;
      connect();
    }
  };
}

// What is sent while the socket is not open is dropped.
function send(data) {
  if (session.socket?.readyState === WebSocket.OPEN) {
    session.socket.send(data);
  }
}

function sendText(message) {
  send(JSON.stringify(message));
}

// A key moves the session's end as an extend does, so it takes the
// warning down.
function sendKeys(bytes) {
  panel.warning.hidden = true;
  send(bytes);
}

function warn(seconds) {
  panel.warningText.textContent = "The session ends in " + seconds + " seconds.";
  panel.warning.hidden = false;
}

// A paste is one input, bracketed as the shell asks the terminal to, so
// that nothing runs until Enter; one made before the shell has asked waits
// for its prompt.
function pasteWaiting() {
  if (session.terminal.modes.bracketedPasteMode) {
    for (const text of session.pastes.splice(0)) {
      session.terminal.paste(text);
    }
  }
}

function stopSession() {
  sendText({ stop: true });
}

// A restart stops the session and connects anew at the close, or at once
// where no socket is open.
function restartSession() {
  if (session.socket === null || session.socket.readyState === WebSocket.CLOSED) {
    startSession();
  } else {
    session.restarting = true;
    stopSession();
  }
}

function focusTerminal() {
  if (session.terminal !== null) {
    session.terminal.focus();
  } else {
    panel.terminal.focus();
  }
}

// The session's state, as the panel's bar names it.
function setState(state) {
  panel.running = state === "connecting" || state === "running";
  panel.state.textContent = state;
  const started = session.socket !== null;
  panel.start.replaceChildren(icon(started ? "rotate-ccw" : "play"), started ? "Restart" : "Start");
  panel.stop.disabled = !panel.running;
  showWaiting();
}

function pasteIntoShell(text) {
  if (phone.matches) {
    remember("ernest.paste", text);
    location.assign("shell.html");
    return;
  }
  if (panel.layout === null && !panel.onPage) {
    openPanel(remembered("ernest.panel", "beside"));
  }
  session.pastes.push(text.trimEnd());
  if (!panel.running) {
    startSession();
  } else {
    pasteWaiting();
  }
  focusTerminal();
}

// The handle on the panel's inner edge sets its width beside, or its
// height below, as a share of the window, kept for the next page.
function addHandle(handle) {
  handle.addEventListener("pointerdown", (down) => {
    handle.setPointerCapture(down.pointerId);
    const move = (event) => {
      if (panel.layout === "beside") {
        const share = 1 - event.clientX / window.innerWidth;
        setSize("width", Math.min(0.7, Math.max(0.25, share)));
      } else {
        const share = 1 - event.clientY / window.innerHeight;
        setSize("height", Math.min(0.75, Math.max(0.2, share)));
      }
    };
    handle.addEventListener("pointermove", move);
    handle.addEventListener("pointerup", () => handle.removeEventListener("pointermove", move),
      { once: true });
  });
}

function setSize(dimension, share) {
  document.documentElement.style.setProperty("--panel-" + dimension, (share * 100).toFixed(1) + "%");
  remember("ernest.panel." + dimension, share.toFixed(3));
}

function addPanel() {
  // The page's main and footer scroll together beside or above the panel.
  const page = document.createElement("div");
  page.className = "page";
  document.querySelector("header").after(page);
  page.append(document.querySelector("main"), document.querySelector("footer"));

  const element = document.createElement("aside");
  element.className = "shell-panel";
  element.setAttribute("aria-label", "Ernest shell");
  element.hidden = true;

  const handle = document.createElement("div");
  handle.className = "panel-handle";
  handle.setAttribute("aria-hidden", "true");
  addHandle(handle);

  const bar = document.createElement("div");
  bar.className = "panel-bar";
  const state = document.createElement("span");
  state.className = "panel-state";
  const start = document.createElement("button");
  start.type = "button";
  start.className = "panel-button";
  start.addEventListener("click", restartSession);
  const stop = document.createElement("button");
  stop.type = "button";
  stop.className = "panel-button";
  stop.append(icon("square"), "Stop");
  stop.addEventListener("click", stopSession);
  const hide = iconButton("panel-right", "Hide the shell; it keeps running", "icon-button", closePanel);
  bar.append(state, start, stop, hide);

  // The warning before a session's end, a banner and no dialog.
  const warning = document.createElement("div");
  warning.className = "panel-warning";
  warning.hidden = true;
  const warningText = document.createElement("span");
  const extend = document.createElement("button");
  extend.type = "button";
  extend.className = "panel-button";
  extend.textContent = "Extend";
  extend.addEventListener("click", () => {
    warning.hidden = true;
    sendText({ extend: true });
    focusTerminal();
  });
  warning.append(warningText, extend);

  const terminal = document.createElement("div");
  terminal.className = "panel-terminal";
  terminal.tabIndex = 0;
  terminal.setAttribute("aria-label", "The shell's terminal");
  terminal.textContent = "Start opens a session, or a Paste does.";

  element.append(handle, bar, warning, terminal);
  page.after(element);
  Object.assign(panel, { element, terminal, state, start, stop, hide, warning, warningText });
  setState("not started");

  for (const dimension of ["width", "height"]) {
    const share = Number(remembered("ernest.panel." + dimension, ""));
    if (share > 0) {
      document.documentElement.style.setProperty("--panel-" + dimension, (share * 100) + "%");
    }
  }
}

function addPanelToggle() {
  const group = document.createElement("div");
  group.className = "panel-toggle";
  group.setAttribute("role", "group");
  group.setAttribute("aria-label", "The shell panel");
  panel.buttons.beside = iconButton("panel-right", "The shell beside the page", "icon-button beside",
    () => toggle("beside"));
  panel.buttons.below = iconButton("panel-bottom", "The shell below the page", "icon-button",
    () => toggle("below"));
  group.append(panel.buttons.beside, panel.buttons.below);
  document.querySelector(".header-inner").append(group);
  wide.addEventListener("change", () => {
    if (panel.layout === "beside") {
      showLayout("below");
    }
  });
}

function addBlockTools(pre) {
  const block = document.createElement("div");
  block.className = "block";
  pre.replaceWith(block);
  block.append(pre);
  const tools = document.createElement("div");
  tools.className = "block-tools";
  if (pre.dataset.shell === "paste" && pre.classList.contains("code")) {
    tools.append(iconButton("terminal", "Paste into the shell", "icon-button",
      () => pasteIntoShell(pre.textContent)));
  }
  tools.append(iconButton("copy", "Copy", "icon-button", () => copy(pre.textContent)));
  block.prepend(tools);
}

// Each input of a transcript ends in its own Paste, visible and muted,
// which puts that input into the shell; the shell's output has none.
function addInputPastes(pre) {
  for (const input of pre.querySelectorAll(".input")) {
    const text = input.textContent.replace(/^> /, "");
    input.append(iconButton("terminal", "Paste into the shell", "line-paste",
      () => pasteIntoShell(text)));
  }
}

// The example's button is the example's alone: it puts the example's code
// into the shell, opening the panel and starting a session where needed,
// and its label never changes. The header shows and hides the panel, and
// the panel's bar starts and stops the session. On a phone the code waits
// on the shell's own page.
function addStart(run) {
  const code = run.closest("section").querySelector("pre.code");
  const button = document.createElement("button");
  button.type = "button";
  button.className = "button primary";
  button.append(icon("terminal"), "Try it");
  button.addEventListener("click", () => pasteIntoShell(code.textContent));
  run.replaceChildren(button);
}

addPanel();
addPanelToggle();
showLayout(null);
if (remembered("ernest.panel.open", "no") === "yes" && !phone.matches) {
  showLayout(layoutFor(remembered("ernest.panel", "beside")));
}
// A block of the page, not the mockup's still picture of a terminal.
for (const pre of document.querySelectorAll("main pre:not(.terminal-frame pre)")) {
  addBlockTools(pre);
  if (pre.dataset.shell === "paste" && pre.classList.contains("transcript")) {
    addInputPastes(pre);
  }
}
for (const run of document.querySelectorAll('[data-shell="start"]')) {
  addStart(run);
}

// The shell's own page holds the panel in its frame, open, and takes an
// input a phone's Paste left waiting.
const frame = document.querySelector(".terminal-frame");
if (frame !== null) {
  panel.onPage = true;
  document.querySelector(".panel-toggle").hidden = true;
  frame.replaceChildren(panel.element);
  panel.element.hidden = false;
  panel.hide.hidden = true;
  const waitingInput = remembered("ernest.paste", "");
  if (waitingInput !== "") {
    remember("ernest.paste", "");
    pasteIntoShell(waitingInput);
  }
}

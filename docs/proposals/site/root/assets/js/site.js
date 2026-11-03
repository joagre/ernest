// What the script adds to a page: the shell panel and its two buttons,
// beside and below, a code block's Copy and Paste, a transcript's Paste
// for each input, its prompt the control, and the example's Start. The
// page reads whole without it. In the mockup the panel's terminal is not
// connected: a Paste shows its input there, and Start and Stop change
// nothing but the panel's state.

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

// Beside needs a wide window; on a narrower one the panel goes below.
const wide = window.matchMedia("(min-width: 1000px)");

const panel = {
  layout: null,
  element: null,
  terminal: null,
  state: null,
  buttons: {},
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
}

function openPanel(wanted) {
  const layout = layoutFor(wanted);
  panel.opener = document.activeElement;
  showLayout(layout);
  remember("ernest.panel", layout);
  remember("ernest.panel.open", "yes");
  panel.terminal.focus();
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

// The session's state, as the panel's bar names it; the mockup's Start
// and Stop move it between the two it can show without a server.
function setState(running) {
  panel.state.textContent = running ? "running · not connected in the mockup" : "not started";
  panel.start.replaceChildren(icon(running ? "rotate-ccw" : "play"), running ? "Restart" : "Start");
  panel.stop.disabled = !running;
}

function pasteIntoShell(text) {
  if (panel.layout === null) {
    openPanel(remembered("ernest.panel", "beside"));
  }
  const line = document.createElement("div");
  line.textContent = "> " + text.trimEnd().replaceAll("\n", "\n  ");
  panel.terminal.append(line);
  panel.terminal.scrollTop = panel.terminal.scrollHeight;
  panel.terminal.focus();
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
  start.addEventListener("click", () => setState(true));
  const stop = document.createElement("button");
  stop.type = "button";
  stop.className = "panel-button";
  stop.append(icon("square"), "Stop");
  stop.addEventListener("click", () => setState(false));
  bar.append(state, start, stop, iconButton("x", "Close the shell", "icon-button", closePanel));

  const terminal = document.createElement("div");
  terminal.className = "panel-terminal";
  terminal.tabIndex = 0;
  terminal.setAttribute("aria-label", "The shell's terminal");
  terminal.textContent = "The shell is not connected in the mockup. A Paste shows its input here.";

  element.append(handle, bar, terminal);
  page.after(element);
  Object.assign(panel, { element, terminal, state, start, stop });
  setState(false);

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

// The input's prompt becomes its Paste: the `> ` shows until hover or
// focus, and then the icon in its place.
function addInputPastes(pre) {
  for (const input of pre.querySelectorAll(".input")) {
    const prompt = input.querySelector(".prompt");
    const text = input.textContent.replace(/^> /, "");
    const button = iconButton("terminal", "Paste into the shell", "prompt-paste",
      () => pasteIntoShell(text));
    button.prepend(prompt.cloneNode(true));
    prompt.replaceWith(button);
  }
}

// On a phone no panel is offered, and the Start stays the link to the
// shell's page.
function addStart(run) {
  if (window.matchMedia("(max-width: 760px)").matches) {
    return;
  }
  const start = document.createElement("button");
  start.type = "button";
  start.className = "button primary";
  start.append(icon("play"), "Start");
  start.addEventListener("click", () => {
    openPanel(remembered("ernest.panel", "beside"));
    setState(true);
  });
  const words = document.createElement("span");
  words.textContent = "Run it yourself, in a shell beside the page.";
  run.replaceChildren(start, words);
}

addPanel();
addPanelToggle();
showLayout(null);
if (remembered("ernest.panel.open", "no") === "yes" && !window.matchMedia("(max-width: 760px)").matches) {
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

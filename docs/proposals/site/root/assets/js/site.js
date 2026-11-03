// What the script adds to a page: the shell panel's toggle, a code
// block's Copy and Paste, a transcript's Paste for each input, its prompt
// the control, and the example's Start. The page reads whole without it. In the mockup the shell is not
// connected, so Paste, Start and the toggle do nothing yet; Copy copies.

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

function pasteIntoShell(text) {
  // The session client's, the plan's MVP 4.2 item 4.
}

function addPanelToggle() {
  const group = document.createElement("div");
  group.className = "panel-toggle";
  group.setAttribute("role", "group");
  group.setAttribute("aria-label", "The shell panel");
  group.append(
    iconButton("panel-right", "Open the shell beside the page", "icon-button", () => {}),
    iconButton("panel-bottom", "Open the shell below the page", "icon-button", () => {}),
  );
  document.querySelector(".header-inner").append(group);
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
  const words = document.createElement("span");
  words.textContent = "Run it yourself, in a shell beside the page.";
  run.replaceChildren(start, words);
}

addPanelToggle();
for (const pre of document.querySelectorAll("main pre")) {
  addBlockTools(pre);
  if (pre.dataset.shell === "paste" && pre.classList.contains("transcript")) {
    addInputPastes(pre);
  }
}
for (const run of document.querySelectorAll('[data-shell="start"]')) {
  addStart(run);
}

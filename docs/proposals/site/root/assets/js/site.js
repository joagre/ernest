// What the script adds to a page: the shell panel's toggle, a code
// block's Copy and Paste, a transcript's Paste for each input, and Try's
// Start. The page reads whole without it. In the mockup the shell is not
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

function addInputPastes(pre) {
  for (const input of pre.querySelectorAll(".input")) {
    const text = input.textContent.replace(/^> /, "");
    input.prepend(iconButton("terminal", "Paste into the shell", "icon-button line-paste",
      () => pasteIntoShell(text)));
  }
}

function addStart(door) {
  const start = document.createElement("button");
  start.type = "button";
  start.className = "button primary";
  start.append(icon("play"), "Start");
  door.querySelector("a > .icon:last-child").remove();
  door.append(start);
}

addPanelToggle();
for (const pre of document.querySelectorAll("main pre")) {
  addBlockTools(pre);
  if (pre.dataset.shell === "paste" && pre.classList.contains("transcript")) {
    addInputPastes(pre);
  }
}
for (const door of document.querySelectorAll('[data-shell="start"]')) {
  addStart(door);
}

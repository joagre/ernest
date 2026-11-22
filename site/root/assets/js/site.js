// What the script adds to a page (docs/design/site.md, *The
// live shell*): the shell panel and its two buttons, beside and below, with
// its session through the server's client; a code block's Copy, Paste and
// Load, a transcript's Paste for each input, and the example's Try it; the
// navigation that keeps the panel from page to page; the shell page's
// numbers, the server's limits; and the sidebar's mark on the section being
// read. The page reads whole without it, but for the shell page's numbers.

// The icons' file, which the page names on this script's element, its name
// holding a digest of its content as this script's does (site.md *The
// templates*).
const script = document.currentScript;
const here = script.src;
const icons = new URL(script.dataset.icons, document.baseURI);

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

function textButton(name, label, action) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "panel-button";
    button.append(icon(name), label);
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
const wide = window.matchMedia("(width >= 62.5em)");
const phone = window.matchMedia("(width <= 47.5em)");

// The panel: its layout, beside, below or hidden, null; its element and
// its parts; whether a session runs, connecting or running; whether it
// stands in the shell page's frame; and what had the focus when it opened.
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
        panel.hide.replaceChildren(icon(layoutIcon(layout)));
        showHandle();
    }
    showWaiting();
}

function layoutIcon(layout) {
    return layout === "beside" ? "panel-right" : "panel-bottom";
}

// A session that runs while the panel is hidden marks the button that
// brings it back.
function showWaiting() {
    const waiting = panel.running && panel.layout === null && !panel.onPage;
    const last = layoutFor(remembered("ernest.panel", "beside"));
    for (const [name, button] of Object.entries(panel.buttons)) {
        button.classList.toggle("waiting", waiting && name === last);
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

// Closing returns the focus to what opened the panel, or, where that is
// gone with its page or was no control, to the header's button.
function closePanel() {
    const layout = panel.layout;
    const within = panel.element.contains(document.activeElement);
    showLayout(null);
    remember("ernest.panel.open", "no");
    if (within) {
        const opener = panel.opener?.isConnected && panel.opener !== document.body ?
            panel.opener : panel.buttons[layout];
        opener?.focus();
    }
}

function toggle(layout) {
    if (panel.layout === layout) {
        closePanel();
    } else {
        openPanel(layout);
    }
}

//
// The session
//

// xterm.js over the server's client, an ES module the server serves at the
// site's address for it, whose interface is the server's design's *The
// client*: a session started at the terminal's size, its keys, a resize, an
// extend and a stop; and told the output, the attach, whether this browser
// joined a live session, the warning with the milliseconds left, and the
// end by its name. xterm.js and the client are loaded only when a session
// starts, so that a page read without the shell fetches neither, but the
// shell's page, which imports the client at its load for its limits.
const clientPath = "/shell/client.js";

// The session's seven states, each the bar's word and the mark at a
// session's end: connecting, running and disconnected, the page's own, and
// one for each end the client names, a lost session being a dropped
// connection.
const endings = {
    expired: "expired",
    takenOver: "taken over",
    unavailable: "unavailable",
    stopped: "stopped",
    lost: "disconnected",
};
const encoder = new TextEncoder();
const session = {
    client: null,
    handle: null,
    terminal: null,
    fit: null,
    pastes: [],
    restarting: false,
    joined: false,
    spoken: false,
    clear: false,
};

function loadScript(src) {
    return new Promise((resolve, reject) => {
        const element = document.createElement("script");
        element.src = src;
        element.onload = resolve;
        element.onerror = reject;
        document.head.append(element);
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
            .then(() => loadScript(new URL("addon-fit.js", here)))
            .catch((failure) => {
                style.remove();
                xtermLoaded = null;
                throw failure;
            });
    }
    return xtermLoaded;
}

// The client, imported once for a document; one that does not load is
// imported again at the next start.
let clientLoaded = null;

function loadClient() {
    if (clientLoaded === null) {
        clientLoaded = import(clientPath).catch((failure) => {
            clientLoaded = null;
            throw failure;
        });
    }
    return clientLoaded;
}

function token(name) {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

// The terminal's text is .875rem, in the pixels xterm.js takes, so that it
// follows the reader's font size as the page's does.
function terminalSize() {
    return 0.875 * parseFloat(getComputedStyle(document.documentElement).fontSize);
}

// A terminal or a client that does not load leaves no session, in the
// page's own word for a connection lost, and the next start loads it again.
// A second start made while they load finds the first's session when they
// come, and starts none.
async function startSession() {
    try {
        [session.client] = await Promise.all([loadClient(), loadXterm()]);
    } catch {
        setState("disconnected");
        return;
    }
    if (session.terminal === null) {
        panel.terminal.replaceChildren();
        const terminal = new Terminal({
            screenReaderMode: true,
            macOptionIsMeta: true,
            fontFamily: token("--mono"),
            fontSize: terminalSize(),
            theme: { background: token("--terminal"), foreground: token("--terminal-ink") },
        });
        const fit = new FitAddon.FitAddon();
        terminal.loadAddon(fit);
        terminal.open(panel.terminal);
        terminal.onData((data) => sendKeys(encoder.encode(data)));
        terminal.onBinary((data) => sendKeys(Uint8Array.from(data, (char) => char.charCodeAt(0))));
        terminal.onResize((size) => session.handle?.resize(size.rows, size.cols));
        // The shell takes Tab, Shift-Tab and Escape, so F6, which report
        // §11.2's editor binds to nothing, moves the focus out of the terminal
        // to the panel's controls (site.md *The live shell*).
        terminal.attachCustomKeyEventHandler((event) => {
            if (event.key !== "F6") {
                return true;
            }
            if (event.type === "keydown") {
                event.preventDefault();
                panel.start.focus();
            }
            return false;
        });
        new ResizeObserver(() => {
            if (!panel.element.hidden) {
                fit.fit();
            }
        }).observe(panel.terminal);
        Object.assign(session, { terminal, fit });
    }
    session.fit.fit();
    if (session.handle === null) {
        connect();
    }
}

// A session started at the terminal's size, its handle kept until it ends.
function connect() {
    session.joined = false;
    session.spoken = false;
    setState("connecting");
    session.handle = session.client.start(session.terminal.rows, session.terminal.cols, {
        output: (bytes) => {
            session.spoken = true;
            session.terminal.write(bytes, pasteWaiting);
        },
        attached,
        warning: warn,
        ended,
    });
}

// A restart starts on a clear screen; a start after an end keeps the ended
// session's screen above the new one. A session this browser joined, after
// a whole page's load or in another tab, has a shell that drew its prompt
// on an earlier terminal, so it is asked to draw its line again, C-l.
function attached(joined) {
    if (session.clear) {
        session.terminal.reset();
        session.clear = false;
    }
    session.terminal.options.disableStdin = false;
    setState("running");
    focusTerminal();
    if (joined) {
        session.joined = true;
        session.handle.keys(new Uint8Array([12]));
    }
}

function ended(reason) {
    session.handle = null;
    panel.warning.hidden = true;
    const ending = endings[reason];
    setState(ending);
    if (session.restarting) {
        session.restarting = false;
        session.clear = true;
        connect();
    } else {
        markEnd(ending);
        if (ending === "expired") {
            expired();
        }
    }
}

// A session's end is marked where its output ends, dim, in the bar's word
// for it, and the terminal takes no keys until a new one starts; its
// screen stays to be read.
function markEnd(ending) {
    session.terminal.write("\r\n\x1b[2m" + ending + "\x1b[0m\r\n");
    session.terminal.options.disableStdin = true;
}

// A key moves the session's end as an extend does, so it takes the
// warning down. What is sent where no session runs is dropped.
function sendKeys(bytes) {
    panel.warning.hidden = true;
    session.handle?.keys(bytes);
}

// The warning says once the seconds it carries; nothing counts down, since
// a key moves the server's deadline without a word.
function warn(left) {
    panel.warningText.textContent = "The session ends in " + Math.round(left / 1000) +
        " seconds.";
    panel.warning.hidden = false;
}

// A paste is one input, bracketed as the shell asks the terminal to, so
// that nothing runs until Enter. One for a session that is starting waits
// for the session's first output, as a person waits for the prompt: what
// the terminal is sent before the shell claims it, it echoes (report
// §11.2 keeps the keys themselves for the first prompt). A joined
// session's shell asked an earlier terminal, so its pastes are bracketed
// here. A Load's typed line follows its paste's Enter.
function pasteWaiting() {
    if (!session.spoken) {
        return;
    }
    const asked = session.terminal.modes.bracketedPasteMode;
    for (const { text, typed } of session.pastes.splice(0)) {
        if (asked || !session.joined) {
            session.terminal.paste(text);
        } else {
            sendKeys(encoder.encode("\x1b[200~" + text.replace(/\r?\n/g, "\r") + "\x1b[201~"));
        }
        if (typed !== "") {
            sendKeys(encoder.encode("\r" + typed));
        }
    }
}

// A stop asked for before the session is attached is the client's to
// order.
function stopSession() {
    session.handle?.stop();
}

// A restart stops the session and starts anew at its end, or at once where
// none runs.
function restartSession() {
    if (session.handle === null) {
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

// The session's state, as the panel's bar names it, which a screen reader
// announces once as it changes.
function setState(state) {
    panel.running = state === "connecting" || state === "running";
    panel.state.textContent = state;
    // Restart only while a session runs: after an end there is none to restart.
    panel.start.replaceChildren(icon(panel.running ? "rotate-ccw" : "play"),
        panel.running ? "Restart" : "Start");
    panel.stop.disabled = !panel.running;
    showWaiting();
}

// A Paste or a Load is the visitor asking for the shell: it opens the
// panel where none shows and starts a session where none runs. On a phone
// the input waits on the shell's own page.
function pasteIntoShell(text, typed = "") {
    if (phone.matches && !panel.onPage) {
        remember("ernest.paste", text);
        remember("ernest.typed", typed);
        location.assign("/shell/");
        return;
    }
    if (panel.layout === null && !panel.onPage) {
        openPanel(remembered("ernest.panel", "beside"));
    }
    session.pastes.push({ text: text.trimEnd(), typed });
    if (!panel.running) {
        startSession();
    } else {
        pasteWaiting();
    }
    focusTerminal();
}

//
// A session's end, when it expires
//

// An expired session closes its panel, giving the page back its width, and
// a slim notice at the window's bottom says why and offers a new session,
// until the visitor clicks it or anywhere on the page, or presses Escape
// outside the terminal; the layout kept is unchanged. On the shell's own
// page the panel stays, its end marked in it.
function expired() {
    if (panel.onPage) {
        return;
    }
    if (panel.layout !== null) {
        closePanel();
    }
    const sentence = document.createElement("span");
    sentence.textContent = "The shell ended after " + spoken(session.client.limits.lifetime) +
        " without a key; opening it starts a new one.";
    const open = iconButton(layoutIcon(layoutFor(remembered("ernest.panel", "beside"))),
        "Open the shell", "icon-button", () => {
            openPanel(remembered("ernest.panel", "beside"));
            startSession();
        });
    // Its own click closes the notice, as any click on the page does.
    const close = iconButton("x", "Close this notice", "icon-button", () => {});
    panel.notice.replaceChildren(sentence, open, close);
}

function addNotice() {
    // A polite live region, in the page from its load, so that what it is
    // given is announced; empty, it shows nothing.
    const notice = document.createElement("div");
    notice.className = "notice";
    notice.setAttribute("role", "status");
    document.body.append(notice);
    panel.notice = notice;
    const dismiss = () => notice.replaceChildren();
    document.addEventListener("click", dismiss);
    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && !panel.element.contains(event.target)) {
            dismiss();
        }
    });
}

//
// The panel
//

// The handle on the panel's inner edge sets its width beside, or its
// height below, as a share of the window, kept for the next page: dragged,
// or by the arrow keys where it has the focus.
function addHandle(handle) {
    handle.addEventListener("pointerdown", (down) => {
        handle.setPointerCapture(down.pointerId);
        const move = (event) => {
            if (panel.layout === "beside") {
                setSize("width", 1 - event.clientX / window.innerWidth);
            } else {
                setSize("height", 1 - event.clientY / window.innerHeight);
            }
        };
        handle.addEventListener("pointermove", move);
        handle.addEventListener("pointerup", () => handle.removeEventListener("pointermove", move),
            { once: true });
    });
    handle.addEventListener("keydown", (event) => {
        const steps = panel.layout === "beside" ?
            { ArrowLeft: 0.05, ArrowRight: -0.05 } : { ArrowUp: 0.05, ArrowDown: -0.05 };
        if (event.key in steps) {
            event.preventDefault();
            const dimension = panel.layout === "beside" ? "width" : "height";
            setSize(dimension, share(dimension) + steps[event.key]);
        }
    });
}

const bounds = { width: [0.25, 0.7], height: [0.2, 0.75] };

function share(dimension) {
    const size = panel.element.getBoundingClientRect();
    return dimension === "width" ?
        size.width / window.innerWidth : size.height / window.innerHeight;
}

function setSize(dimension, wanted) {
    const [least, most] = bounds[dimension];
    const bounded = Math.min(most, Math.max(least, wanted));
    const percent = (bounded * 100).toFixed(1) + "%";
    document.documentElement.style.setProperty("--panel-" + dimension, percent);
    remember("ernest.panel." + dimension, bounded.toFixed(3));
    showHandle();
}

// The handle is a separator whose value is the panel's share of the window.
function showHandle() {
    const beside = panel.layout === "beside";
    const dimension = beside ? "width" : "height";
    panel.handle.setAttribute("aria-orientation", beside ? "vertical" : "horizontal");
    panel.handle.setAttribute("aria-valuemin", String(bounds[dimension][0] * 100));
    panel.handle.setAttribute("aria-valuemax", String(bounds[dimension][1] * 100));
    const kept = Number(remembered("ernest.panel." + dimension, ""));
    const now = kept > 0 ? kept : dimension === "width" ? 0.45 : 0.4;
    panel.handle.setAttribute("aria-valuenow", String(Math.round(now * 100)));
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
    handle.tabIndex = 0;
    handle.setAttribute("role", "separator");
    handle.setAttribute("aria-label", "The shell panel's size");
    addHandle(handle);

    const bar = document.createElement("div");
    bar.className = "panel-bar";
    const state = document.createElement("span");
    state.className = "panel-state";
    state.setAttribute("role", "status");
    const start = textButton("play", "Start", restartSession);
    const stop = textButton("square", "Stop", stopSession);
    const hide = iconButton("panel-right", "Hide the shell", "icon-button", closePanel);
    bar.append(state, start, stop, hide);

    // The warning before a session's end, a banner and no dialog.
    const warning = document.createElement("div");
    warning.className = "panel-warning";
    warning.setAttribute("role", "alert");
    warning.hidden = true;
    const warningText = document.createElement("span");
    const extend = document.createElement("button");
    extend.type = "button";
    extend.className = "panel-button";
    extend.textContent = "Extend";
    extend.addEventListener("click", () => {
        warning.hidden = true;
        session.handle?.extend();
        focusTerminal();
    });
    warning.append(warningText, extend);

    const terminal = document.createElement("div");
    terminal.className = "panel-terminal";
    terminal.tabIndex = -1;
    const note = document.createElement("p");
    note.className = "panel-note";
    note.textContent = "Start opens a session, or a Paste does.";
    terminal.append(note);

    element.append(handle, bar, warning, terminal);
    page.after(element);
    Object.assign(panel,
        { element, handle, terminal, state, start, stop, hide, warning, warningText });
    setState("");

    for (const dimension of ["width", "height"]) {
        const kept = Number(remembered("ernest.panel." + dimension, ""));
        if (kept > 0) {
            document.documentElement.style.setProperty("--panel-" + dimension, (kept * 100) + "%");
        }
    }
}

function addPanelToggle() {
    const group = document.createElement("div");
    group.className = "panel-toggle";
    group.setAttribute("role", "group");
    group.setAttribute("aria-label", "The shell panel");
    panel.buttons.beside = iconButton("panel-right", "The shell beside the page",
        "icon-button beside", () => toggle("beside"));
    panel.buttons.below = iconButton("panel-bottom", "The shell below the page", "icon-button",
        () => toggle("below"));
    group.append(panel.buttons.beside, panel.buttons.below);
    document.querySelector(".header-inner").append(group);
    panel.toggle = group;
    wide.addEventListener("change", () => {
        if (panel.layout === "beside") {
            showLayout("below");
        }
    });
}

// The shell's own page holds the panel in its frame, with no hide, no
// handle and no header buttons, and takes an input a phone's Paste left
// waiting. Leaving it, the panel goes back beside or below the page.
function placePanel() {
    const frame = document.querySelector("main .terminal-frame");
    if (frame !== null) {
        showLayout(null);
        panel.onPage = true;
        frame.replaceChildren(panel.element);
        panel.element.hidden = false;
        panel.toggle.hidden = true;
        panel.hide.hidden = true;
        panel.handle.hidden = true;
        const waitingInput = remembered("ernest.paste", "");
        if (waitingInput !== "") {
            remember("ernest.paste", "");
            pasteIntoShell(waitingInput, remembered("ernest.typed", ""));
        }
    } else if (panel.onPage) {
        panel.onPage = false;
        document.querySelector(".page").after(panel.element);
        panel.toggle.hidden = false;
        panel.hide.hidden = false;
        panel.handle.hidden = false;
        showLayout(layoutFor(remembered("ernest.panel", "beside")));
        remember("ernest.panel.open", "yes");
    }
}

//
// The shell page's limits
//

// The server's limits, which the client answers, each written into the
// shell page's span that names it, in place of the words the page reads
// without the script (site.md *The other pages*): a time spoken, a count
// in digits. A client that does not load leaves the words.
const limitsSaid = {
    "lifetime": (limits) => spoken(limits.lifetime),
    "warning": (limits) => spoken(limits.warning),
    "mostAtOnce": (limits) => String(limits.mostAtOnce),
    "starts.count": (limits) => String(limits.starts.count),
    "starts.within": (limits) => spoken(limits.starts.within),
};

function showLimits() {
    const spans = document.querySelectorAll("main [data-limit]");
    if (spans.length === 0) {
        return;
    }
    loadClient().then(({ limits }) => {
        for (const span of spans) {
            span.textContent = limitsSaid[span.dataset.limit](limits);
        }
    }, () => {});
}

// A time in milliseconds as a page says it, in the largest unit it is a
// whole number of: `5 minutes`, `a minute`, `an hour`.
const units = [
    [3600000, "an hour", "hours"],
    [60000, "a minute", "minutes"],
    [1000, "a second", "seconds"],
    [1, "a millisecond", "milliseconds"],
];

function spoken(ms) {
    const unit = units.find(([size]) => ms % size === 0);
    if (unit === undefined) {
        return ms + " milliseconds";
    }
    const [size, one, many] = unit;
    return ms === size ? one : ms / size + " " + many;
}

//
// A page's code blocks
//

// A block's tools stand over its upper right corner where its first line
// leaves them room, and on a row of their own above it where it does not:
// the first line is measured against the room the tools leave in the
// corner, when the tools are made and again whenever the block's code
// changes size, which the observer says. The rule is one under a mouse and
// on a touch screen, and names no width (site.md *The live shell*). A
// page put in place of another observes its own blocks.
let placing = null;

function placeTools(entries) {
    const blocks = entries.map((entry) => entry.target.parentElement);
    for (const block of blocks) {
        block.classList.remove("tools-above");
    }
    const above = blocks.map((block) =>
        firstLineEnd(block.querySelector("pre")) > block.querySelector(".block-tools")
            .getBoundingClientRect().left);
    blocks.forEach((block, index) => block.classList.toggle("tools-above", above[index]));
}

// Where a block's first line ends, as the code lays it out, however far
// the block is scrolled sideways: its text up to its first line feed, an
// input's Paste among it.
function firstLineEnd(pre) {
    const line = document.createRange();
    line.selectNodeContents(pre);
    const walker = document.createTreeWalker(pre, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
        const newline = walker.currentNode.data.indexOf("\n");
        if (newline >= 0) {
            line.setEnd(walker.currentNode, newline);
            break;
        }
    }
    return line.getBoundingClientRect().right + pre.scrollLeft;
}

function addBlockTools(pre) {
    const block = document.createElement("div");
    block.className = "block";
    pre.replaceWith(block);
    block.append(pre);
    // A declaration's signature is read, not typed into a shell: no tools.
    if (pre.dataset.tools === "none") {
        return;
    }
    const tools = document.createElement("div");
    tools.className = "block-tools";
    if (pre.dataset.shell === "paste" && pre.classList.contains("code")) {
        tools.append(iconButton("terminal", "Paste into the shell", "icon-button",
            () => pasteIntoShell(pre.textContent)));
    }
    // A program's block is loaded: its declarations pasted as one input, and
    // then `main()` typed, one Enter away.
    if (pre.dataset.shell === "load") {
        tools.append(iconButton("play", "Load into the shell", "icon-button",
            () => pasteIntoShell(pre.textContent, "main()")));
    }
    tools.append(iconButton("copy", "Copy", "icon-button", () => copy(pre.textContent)));
    block.prepend(tools);
    placing.observe(pre);
}

// Each input of a transcript ends in its own Paste, a small button always
// shown, which puts that input into the shell; the shell's output has none.
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

// The sidebar names the section being read: the last heading above the
// window's upper part is the one read, and its link is kept in view in the
// sidebar's own scroll. The page scrolls in the window, or in its own
// column beside the shell panel, so a scroll of either moves it. A page
// put in place of another follows its own sidebar.
let following = null;

function followReading() {
    if (following !== null) {
        document.removeEventListener("scroll", following, true);
        following = null;
    }
    const sidebar = document.querySelector(".contents details");
    if (sidebar === null) {
        return;
    }
    const links = new Map();
    for (const link of sidebar.querySelectorAll('a[href^="#"]')) {
        links.set(decodeURIComponent(link.hash.slice(1)), link);
    }
    const headings = [...document.querySelectorAll(".article [id]")].filter((h) => links.has(h.id));
    let current = null;
    let pending = false;
    const update = () => {
        pending = false;
        const line = window.innerHeight * 0.25;
        // Before the first heading reaches the line, nothing is being read.
        let reading = null;
        for (const heading of headings) {
            if (heading.getBoundingClientRect().top <= line) {
                reading = heading;
            } else {
                break;
            }
        }
        const link = reading === null ? null : links.get(reading.id);
        if (link === current) {
            return;
        }
        current?.removeAttribute("aria-current");
        current = link;
        if (link === null) {
            return;
        }
        link.setAttribute("aria-current", "location");
        const box = sidebar.getBoundingClientRect();
        const at = link.getBoundingClientRect();
        if (at.top < box.top || at.bottom > box.bottom) {
            sidebar.scrollTop += at.top - box.top - box.height / 3;
        }
    };
    following = () => {
        if (!pending) {
            pending = true;
            requestAnimationFrame(update);
        }
    };
    document.addEventListener("scroll", following, true);
    update();
}

// What the script adds to a page's main, at its load and when a page is
// put in place of another.
function addToPage() {
    placing?.disconnect();
    placing = new ResizeObserver(placeTools);
    // A block of the page, not a still picture of a terminal.
    for (const pre of document.querySelectorAll("main pre:not(.terminal-frame pre)")) {
        addBlockTools(pre);
        if (pre.dataset.shell === "paste" && pre.classList.contains("transcript")) {
            addInputPastes(pre);
        }
    }
    for (const run of document.querySelectorAll('main [data-shell="start"]')) {
        addStart(run);
    }
    followReading();
    placePanel();
    showLimits();
}

//
// The navigation that keeps the panel
//

// While the panel shows, or its session runs, a link to another page of
// the site fetches that page and puts its main, its footer, its header's
// links and its title in place of the old, the address moved by the
// history, so that the panel, its session and its screen stay; back,
// forward, the scroll, an anchor and the focus then behave as on a page
// loaded whole. Otherwise, and on a phone, a link loads its page whole.
// Every page stays a whole file, and one that names another script or
// stylesheet, a newer site's, is loaded whole. No page counts as shown while
// one is on its way, so that a link or a move through the history made
// meanwhile fetches its own page, even the one still in view, and the
// visitor's last word holds.
let shown = location.pathname;
let navigations = 0;

function keepsPanel() {
    return !phone.matches && (panel.layout !== null || panel.running);
}

// The element the page scrolls in: its own column beside or above the
// panel, or the window.
function scroller() {
    return panel.layout !== null && !panel.onPage ?
        document.querySelector(".page") : document.scrollingElement;
}

function keepScroll() {
    history.replaceState({ ...history.state, scroll: scroller().scrollTop }, "");
}

function pageLink(event) {
    const link = event.target.closest?.("a[href]");
    if (link === null || link === undefined || event.defaultPrevented || event.button !== 0
            || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey
            || (link.target !== "" && link.target !== "_self") || link.hasAttribute("download")) {
        return null;
    }
    const url = new URL(link.href, location.href);
    const isPage = url.pathname.endsWith("/") || url.pathname.endsWith(".html");
    return url.origin === location.origin && isPage && !url.pathname.startsWith("/assets/") ?
        url : null;
}

function followLink(event) {
    const url = pageLink(event);
    if (url === null) {
        return;
    }
    if (url.pathname === shown && url.search === location.search) {
        // Another place on the same page: the browser's own, the scroll kept
        // for the way back.
        if (url.hash !== "") {
            keepScroll();
        }
        return;
    }
    if (keepsPanel()) {
        event.preventDefault();
        navigate(url, null, true);
    }
}

async function navigate(url, state, pushed) {
    const navigation = ++navigations;
    shown = null;
    let page;
    try {
        const response = await fetch(url, { headers: { Accept: "text/html" } });
        const type = response.headers.get("Content-Type") ?? "";
        if ((!response.ok && response.status !== 404) || !type.startsWith("text/html")) {
            throw new Error("not a page");
        }
        page = new DOMParser().parseFromString(await response.text(), "text/html");
    } catch {
        if (navigation === navigations) {
            location.assign(url);
        }
        return;
    }
    if (navigation !== navigations) {
        return;
    }
    const named = (selector, attribute) =>
        [document, page].map((each) => each.querySelector(selector)?.getAttribute(attribute));
    const [oldScript, newScript] = named("script[src]", "src");
    const [oldStyle, newStyle] = named('link[rel="stylesheet"]', "href");
    if (page.querySelector("main") === null || oldScript !== newScript || oldStyle !== newStyle) {
        location.assign(url);
        return;
    }
    if (pushed) {
        keepScroll();
        history.pushState({ scroll: 0 }, "", url);
    }
    history.scrollRestoration = "manual";
    shown = url.pathname;
    putInPlace(page);
    arrive(url, state);
}

function putInPlace(page) {
    document.title = page.title;
    for (const selector of [".site-nav", ".site-menu nav", "main", "footer"]) {
        const replacement = document.adoptNode(page.querySelector(selector));
        document.querySelector(selector).replaceWith(replacement);
    }
    document.querySelector(".site-menu").open = false;
    addToPage();
}

// A page put in place of another: the scroll the history kept for it, or
// its anchor's, or its top; the focus where a page loaded whole has it,
// at the anchor or the top; and its title said, as a screen reader says a
// page's at its load.
function arrive(url, state) {
    const target = scrolled(url, state);
    focusStart(target ?? document.body);
    panel.announcer.textContent = document.title;
}

function scrolled(url, state) {
    const target = url.hash === "" ? null :
        document.getElementById(decodeURIComponent(url.hash.slice(1)));
    if (typeof state?.scroll === "number") {
        scroller().scrollTop = state.scroll;
    } else if (target !== null) {
        target.scrollIntoView();
    } else {
        scroller().scrollTop = 0;
    }
    return target;
}

// The place the next Tab starts from, without a mark the page keeps.
function focusStart(element) {
    const had = element.getAttribute("tabindex");
    element.setAttribute("tabindex", "-1");
    element.focus({ preventScroll: true });
    if (had === null) {
        element.removeAttribute("tabindex");
    }
}

function addNavigation() {
    const announcer = document.createElement("div");
    announcer.className = "announcer";
    announcer.setAttribute("role", "status");
    document.body.append(announcer);
    panel.announcer = announcer;
    document.addEventListener("click", followLink);
    // Back or forward to another place on the same page moves its scroll
    // alone, as on a page loaded whole.
    window.addEventListener("popstate", (event) => {
        const url = new URL(location.href);
        if (url.pathname !== shown) {
            navigate(url, event.state, false);
        } else if (typeof event.state?.scroll === "number" || url.hash !== "") {
            scrolled(url, event.state);
        }
    });
}

addPanel();
addPanelToggle();
addNotice();
addNavigation();
showLayout(null);
if (remembered("ernest.panel.open", "no") === "yes" && !phone.matches
        && document.querySelector("main .terminal-frame") === null) {
    showLayout(layoutFor(remembered("ernest.panel", "beside")));
}
addToPage();

// The stub of the server's client that the browser test serves at
// /shell/client.js (test/ern_browser_tests.erl): the interface of
// ernest-httpd's design's *The client*, with no socket and no shell behind
// it. Each session started stands in `window.stub.sessions` with what the
// page asked of it, its size, its keys and its other asks, which the test
// reads; the test tells the page through the session's `told` and `end`
// what the server would. A session attaches new and writes its prompt, or,
// as `window.stubMode` asks before it starts, attaches joined, answering
// C-l, or holds its prompt until the test calls `prompt`.

export const limits = {
    lifetime: 300000,
    warning: 60000,
    mostAtOnce: 6,
    starts: { count: 10, within: 3600000 },
};

window.stub = { sessions: [] };

const encoder = new TextEncoder();
const decoder = new TextDecoder();

export function start(rows, columns, told) {
    sized(rows, columns);
    for (const member of ["output", "attached", "warning", "ended"]) {
        if (typeof told?.[member] !== "function") {
            throw new TypeError("told." + member + " is not a function");
        }
    }
    const mode = window.stubMode ?? {};
    const session = {
        size: [rows, columns],
        keys: "",
        asked: [],
        told,
        attached: false,
        stopping: false,
        ended: false,
        prompt() {
            told.output(encoder.encode("\x1b[?2004hErnest 9.9.9, session 1. :help for help." +
                "\r\n> "));
        },
        end(reason) {
            if (!session.ended) {
                session.ended = true;
                told.ended(reason);
            }
        },
    };
    window.stub.sessions.push(session);
    setTimeout(() => {
        session.attached = true;
        told.attached(mode.joined === true);
        if (session.stopping) {
            session.end("stopped");
        } else if (!mode.joined && !mode.held) {
            session.prompt();
        }
    });
    return Object.freeze({
        keys(bytes) {
            if (!(bytes instanceof Uint8Array)) {
                throw new TypeError("keys are a Uint8Array");
            }
            if (!session.ended) {
                session.keys += decoder.decode(bytes);
                if (bytes.length === 1 && bytes[0] === 12) {
                    told.output(encoder.encode("\r\x1b[Jdrawn again\r\n> "));
                }
            }
        },
        resize(rows, columns) {
            sized(rows, columns);
            asked(session, "resize");
        },
        extend() {
            asked(session, "extend");
        },
        // A stop before the attach ends the session once it is attached.
        stop() {
            if (asked(session, "stop")) {
                if (session.attached) {
                    setTimeout(() => session.end("stopped"));
                } else {
                    session.stopping = true;
                }
            }
        },
    });
}

// What a session that has not ended is asked, kept; one that has ended
// drops it.
function asked(session, ask) {
    if (!session.ended) {
        session.asked.push(ask);
    }
    return !session.ended;
}

function sized(rows, columns) {
    const isCount = (count) => Number.isInteger(count) && count >= 1 && count <= 65535;
    if (!isCount(rows) || !isCount(columns)) {
        throw new RangeError("rows and columns are integers from 1 to 65535");
    }
}

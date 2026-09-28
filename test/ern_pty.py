#!/usr/bin/env python3
"""A pseudo-terminal for the tests (plan, MVP 2.6).

Runs a command with a terminal of its own, sends bytes when the screen
says the program is ready for them, and hands the screen back.  Erlang has
no way to open a pseudo-terminal, so the terminal path of report section
8.2 -- keys as they are pressed, no echo, the mode restored -- can be
tested no other way.

    ern_pty.py [--timeout S] [--size ROWSxCOLS] [--screen] --steps FILE -- COMMAND

COMMAND runs under /bin/sh.  FILE holds one step a line, and they run in
order; a file rather than arguments, since a step's text holds whatever a
program prints, `>` among it, and no shell should read that.  A blank
line and a line beginning with # are skipped.

    expect:TEXT   wait until TEXT appears on the screen, after whatever
                  the previous expect matched; a colour sequence, ESC [ ... m,
                  is not part of the text, as a reader does not see it
    send:HEX      write those bytes to the terminal
    resize:RxC    give the terminal a new size, as a window manager does
    sleep:MS      wait that long, reading whatever arrives

A step that waits for text is what keeps a test from racing a program
that is slower under load than it was when the test was written; sleep is
for the moments no text marks, such as letting a game run for a tick.
Two lines are printed:

    status <exit code> | timeout
    data <what the program wrote, base64>

With --screen the second line is the screen as a reader would see it,
the writes played onto a grid of the given size: a test of a program
that paints, rather than scrolls, asserts on that and not on the bytes.
"""

import argparse
import base64
import fcntl
import os
import re
import select
import struct
import sys
import termios
import time

import pty as _pty  # after the arguments, so a stray ./pty.py cannot shadow it


def step_spec(text):
    kind, _, arg = text.partition(":")
    if kind == "expect":
        return ("expect", arg.encode("utf-8"))
    if kind == "send":
        return ("send", bytes.fromhex(arg))
    if kind == "sleep":
        return ("sleep", int(arg) / 1000.0)
    if kind == "resize":
        rows, _, columns = arg.partition("x")
        return ("resize", (int(rows), int(columns)))
    raise argparse.ArgumentTypeError(
        "a step is expect:TEXT, send:HEX, resize:RxC, or sleep:MS")


class Screen:
    """What the terminal has shown, and how far the steps have read it."""

    def __init__(self, fd):
        self.fd = fd
        self.seen = bytearray()
        # what has been shown as it reads, without the sequences that only
        # colour it; a sequence a read cut short waits for the next read
        self.plain = bytearray()
        self.partial = b""
        self.cursor = 0
        self.eof = False

    def read(self, seconds):
        readable, _, _ = select.select([self.fd], [], [], seconds)
        if not readable:
            return
        try:
            data = os.read(self.fd, 65536)
        except OSError:
            data = b""
        if data:
            self.seen.extend(data)
            chunk = self.partial + data
            cut = re.search(rb"\x1b(\[[0-9;]*)?$", chunk)
            self.partial = chunk[cut.start():] if cut else b""
            chunk = chunk[:cut.start()] if cut else chunk
            self.plain.extend(re.sub(rb"\x1b\[[0-9;]*m", b"", chunk))
        else:
            self.eof = True

    def find(self, text):
        at = self.plain.find(text, self.cursor)
        if at < 0:
            return False
        self.cursor = at + len(text)
        return True


# What the writes leave on the screen: the cursor moves, the erasures and
# the text, which is all the shell uses. Enough to assert on a pane.
def rendered(data, rows, columns):
    text = data.decode("utf-8", "replace")
    grid = [[" "] * columns for _ in range(rows)]
    row = column = 0
    i = 0
    while i < len(text):
        if text[i] == "\x1b":
            # a private mode, such as bracketed paste: the terminal takes
            # it and shows nothing
            private = re.match(r"\x1b\[\?\d+[hl]", text[i:])
            if private:
                i += private.end()
                continue
            match = re.match(r"\x1b\[(\d*);?(\d*)([A-Za-z])", text[i:])
            if not match:
                i += 1
                continue
            first, second, kind = match.group(1), match.group(2), match.group(3)
            count = int(first or 1)
            if kind == "H":
                row, column = count - 1, int(second or 1) - 1
            elif kind == "A":
                row = max(0, row - count)
            elif kind == "B":
                row = min(rows - 1, row + count)
            elif kind == "C":
                column = min(columns - 1, column + count)
            elif kind == "D":
                column = max(0, column - count)
            elif kind == "K":
                for x in range(column, columns):
                    grid[row][x] = " "
            elif kind == "J":
                if first in ("", "0"):      # from the cursor to the end
                    for x in range(column, columns):
                        grid[row][x] = " "
                    for y in range(row + 1, rows):
                        grid[y] = [" "] * columns
                else:
                    grid = [[" "] * columns for _ in range(rows)]
                    row = column = 0
            i += match.end()
            continue
        character = text[i]
        if character == "\r":
            column = 0
        elif character == "\n":
            row += 1
            if row >= rows:
                grid.pop(0)
                grid.append([" "] * columns)
                row = rows - 1
        elif 0 <= row < rows and 0 <= column < columns:
            grid[row][column] = character
            column += 1
        i += 1
    return "\n".join("".join(line).rstrip() for line in grid)


# Signal the child and wait for it, reading all the while.
def ended_by(pid, screen, signal, grace):
    try:
        os.kill(pid, signal)
    except ProcessLookupError:
        return "timeout"
    until = time.monotonic() + grace
    while time.monotonic() < until:
        screen.read(0.05)
        try:
            ended, wait_status = os.waitpid(pid, os.WNOHANG)
        except ChildProcessError:
            return "timeout"
        if ended:
            return os.waitstatus_to_exitcode(wait_status)
    return None


def run(command, steps, timeout, size):
    pid, fd = _pty.fork()
    if pid == 0:
        os.execvp("/bin/sh", ["/bin/sh", "-c", command])
        os._exit(127)
    def resize(rows, columns):
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))

    rows, _, columns = size.partition("x")
    resize(int(rows), int(columns))
    screen = Screen(fd)
    left = list(steps)
    deadline = time.monotonic() + timeout
    while left and time.monotonic() < deadline and not screen.eof:
        kind, arg = left[0]
        if kind == "send":
            os.write(fd, arg)
            left.pop(0)
        elif kind == "resize":
            resize(*arg)
            left.pop(0)
        elif kind == "expect":
            if screen.find(arg):
                left.pop(0)
            else:
                screen.read(0.02)
        else:
            until = time.monotonic() + arg
            while time.monotonic() < until and not screen.eof:
                screen.read(0.02)
            left.pop(0)
    status = None
    while time.monotonic() < deadline and not screen.eof:
        screen.read(0.02)
        ended, wait_status = os.waitpid(pid, os.WNOHANG)
        if ended:
            status = os.waitstatus_to_exitcode(wait_status)
            break
    if status is None:
        # the screen is read while the child is ending: a program that is
        # still printing fills the terminal's buffer, blocks in its write,
        # and never reaches the signal, so waiting without reading is a
        # deadlock between the two of us
        status = ended_by(pid, screen, 15, 2.0)
        if status is None:
            status = ended_by(pid, screen, 9, 2.0)
        if status is None:
            status = "timeout"
    stop = time.monotonic() + 1.0    # whatever the program wrote as it ended
    while not screen.eof and time.monotonic() < stop:
        before = len(screen.seen)
        screen.read(0.2)
        if len(screen.seen) == before:
            break
    os.close(fd)
    if left:
        print("unmet %s" % " ".join(kind for kind, _ in left), file=sys.stderr)
    return status, bytes(screen.seen)


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("--steps", default=None)
    parser.add_argument("--size", default="24x80")
    parser.add_argument("--screen", action="store_true")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    steps = []
    if args.steps:
        with open(args.steps, "r", encoding="utf-8") as handle:
            steps = [step_spec(line.rstrip("\n")) for line in handle
                     if line.strip() and not line.startswith("#")]
    status, screen = run(" ".join(command), steps, args.timeout, args.size)
    print("status %s" % status)
    if args.screen:
        rows, _, columns = args.size.partition("x")
        screen = rendered(screen, int(rows), int(columns)).encode("utf-8")
    print("data %s" % base64.b64encode(screen).decode("ascii"))


if __name__ == "__main__":
    main()

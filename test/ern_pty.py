#!/usr/bin/env python3
"""A pseudo-terminal for the tests (plan, MVP 2.6).

Runs a command with a terminal of its own, sends bytes at chosen moments,
and hands the screen back.  Erlang has no way to open a pseudo-terminal, so
the terminal path of report section 8.2 -- keys as they are pressed, no
echo, the mode restored -- can be tested no other way.

    ern_pty.py [--timeout S] [--send MS:HEX] ... -- COMMAND

COMMAND runs under /bin/sh.  Each --send writes those bytes that many
milliseconds after the start.  Two lines are printed:

    status <exit code> | timeout
    data <the screen, base64>
"""

import argparse
import base64
import os
import select
import sys
import time

import pty as _pty  # after the arguments, so a stray ./pty.py cannot shadow it


def send_spec(text):
    ms, _, hex_bytes = text.partition(":")
    return int(ms) / 1000.0, bytes.fromhex(hex_bytes)


def run(command, sends, timeout):
    pid, fd = _pty.fork()
    if pid == 0:
        os.execvp("/bin/sh", ["/bin/sh", "-c", command])
        os._exit(127)
    screen = []
    pending = sorted(sends)
    started = time.monotonic()
    status = None
    while time.monotonic() - started < timeout:
        now = time.monotonic() - started
        while pending and now >= pending[0][0]:
            os.write(fd, pending.pop(0)[1])
        readable, _, _ = select.select([fd], [], [], 0.02)
        if readable:
            try:
                data = os.read(fd, 65536)
            except OSError:
                data = b""
            if not data:
                break
            screen.append(data)
            continue
        ended, wait_status = os.waitpid(pid, os.WNOHANG)
        if ended and not pending:
            status = os.waitstatus_to_exitcode(wait_status)
            break
    if status is None:
        try:
            os.kill(pid, 15)
        except ProcessLookupError:
            pass
        try:
            _, wait_status = os.waitpid(pid, 0)
            status = os.waitstatus_to_exitcode(wait_status)
        except ChildProcessError:
            status = "timeout"
    while True:                      # whatever the program wrote as it ended
        readable, _, _ = select.select([fd], [], [], 0.2)
        if not readable:
            break
        try:
            data = os.read(fd, 65536)
        except OSError:
            break
        if not data:
            break
        screen.append(data)
    os.close(fd)
    return status, b"".join(screen)


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("--send", action="append", default=[], type=send_spec)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    status, screen = run(" ".join(command), args.send, args.timeout)
    print("status %s" % status)
    print("data %s" % base64.b64encode(screen).decode("ascii"))


if __name__ == "__main__":
    main()

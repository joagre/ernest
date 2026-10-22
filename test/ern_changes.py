#!/usr/bin/env python3
"""The changes under a directory, for the tests.

Watches the directory given and every directory under it, says `ready`
once it does, and then `changed` each time files there change: one is
made, written, given new times or a new mode, moved or removed.  A read
is no change, so a test that reads the files at each line does not wake
itself.  It ends when its standard input does.

    ern_changes.py DIR

Erlang cannot watch a file system, so a test that waits for what a
program writes without a word, a file one of its processes stored, waits
on this and not on a clock.  It is Linux's inotify, which python3 reaches
through the C library.  A directory made after `ready` is not watched.
"""

import ctypes
import ctypes.util
import os
import select
import sys

# inotify(7): a file written, given new times or a new mode, closed after
# a write, moved out, moved in, made or removed; an open, a read and a
# close after a read are left out
CHANGES = 0x2 | 0x4 | 0x8 | 0x40 | 0x80 | 0x100 | 0x200


def watching(top):
    libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
    fd = libc.inotify_init1(os.O_CLOEXEC)
    if fd < 0:
        raise OSError(ctypes.get_errno(), "inotify_init1")
    for directory, _, _ in os.walk(top):
        if libc.inotify_add_watch(fd, os.fsencode(directory), CHANGES) < 0:
            raise OSError(ctypes.get_errno(), "inotify_add_watch", directory)
    return fd


def main():
    fd = watching(sys.argv[1])
    stdin = sys.stdin.fileno()
    print("ready", flush=True)
    while True:
        readable, _, _ = select.select([fd, stdin], [], [])
        if stdin in readable and not os.read(stdin, 4096):
            return
        if fd in readable:
            os.read(fd, 65536)
            print("changed", flush=True)


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        pass

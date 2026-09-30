# Ernest @VERSION@

Ernest compiled, ready to install on Linux; macOS is expected to work the same way, and is not yet verified. What Ernest is, and where to begin, is `share/doc/ernest/README.md`, which this archive installs.

It needs Erlang/OTP 29 on your `PATH`, make, and a C compiler, for the one part of Ernest in C, the helper that runs another program for `Os.run` and removes a tree for `Fs.removeAll`:

```
make
sudo make install                  # into /usr/local
ern --version
man ern
```

Installing for you alone, with no `sudo`, and removing an installation, are that README's *Installing*. The installation can be moved to another directory whole, and runs there.

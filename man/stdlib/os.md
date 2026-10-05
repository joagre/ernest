# Ernest module Os

*Since 0.1.0.*

The host: the program's command line, its environment and exit status, and
other programs run from it.

Use `arguments`, `environment` and `workingDirectory` to read what the
program was started with, and `exit` to end it with a status. Use `run` to
run another program to its end and read all it wrote, and `start` with
`read` and `write` to talk to one while it runs.

**No shell.** A program is found as the host finds a command: a name without
`/` is looked for in the directories of `PATH`. Each argument reaches it as
it is, so nothing is expanded or quoted; a program that wants a shell runs
`sh` with `-c`.

**A running program is a process.** `start` answers its address, as
`Tcp.connect` answers a socket's. `read` answers what it wrote, a piece at a
time, `write` and `closeInput` feed its input, and `kill` and `monitor` work
on it as on any process. It belongs to the process that started it, and is
killed when that process dies (report Appendix E.23).

## Examples

A program run to its end, and its exit status:

```ernest
Either.map(Os.run(Os.Command(program = "sh", arguments = ["-c", "exit 3"], input = <<>>), 5000),
           fn(finished) = finished.status)
// => Right(3)
```

## See also

`String.fromUtf8` for output that is text, `Io.Error` for why a program
did not run, `Tcp` for the other process a program talks to in bytes.

## Os.Command

```ernest
type Command = Command(program : String, arguments : List(String), input : Bytes)
```

A program to run: its name, its arguments, and the bytes it reads first as
its input.

### Examples

```ernest
Os.Command(program = "wc", arguments = ["-l"], input = String.toUtf8("a\nb\n")).program
// => "wc"
```

## Os.Output

```ernest
type Output = Stdout(Bytes) | Stderr(Bytes) | Exited(Int)
```

A piece of what a running program wrote, to its standard output or its
standard error, and last its exit status. A program a signal ended has the
status 128 plus the signal's number.

### Examples

A program's output read piece by piece, what it wrote and then its exit
status:

```ernest
{
    let program <- Os.start(Os.Command(program = "echo", arguments = ["hi"], input = <<>>));
    let first <- Os.read(program, 5000);
    let second <- Os.read(program, 5000);
    Right(#(first, second))
}
// => Right(#(Stdout(<<104, 105, 10>>), Exited(0)))
```

## Os.Finished

```ernest
type Finished = Finished(status : Int, stdout : Bytes, stderr : Bytes)
```

How a program that `run` ran ended: its exit status, and all it wrote to its
standard output and its standard error.

### Examples

```ernest
Os.Finished(status = 0, stdout = <<>>, stderr = <<>>).status
// => 0
```

## Os.ProgramMsg

```ernest
abstract type ProgramMsg
```

What a running program's process takes. Its constructors are hidden, so a
program uses `Os.read`, `Os.write`, `Os.closeInput` and `Os.give` on it
(report Appendix E.23).

### Examples

The address of a running program, which `read`, `write`, `closeInput` and
`give` take:

```ernest
Os.start(Os.Command(program = "cat", arguments = [], input = <<>>))
```

## Os.arguments

```ernest
Os.arguments : List(String)
```

The words after the module on `ern run`'s command line, whatever they look
like, `-v` among them, bound when the program starts. `ern run` refuses a
word that is not UTF-8. In the shell and under `ern test` there are none.

### Examples

```ernest
match Os.arguments {
    [name] -> Io.println("hello, " <> name)
  | _ -> Io.printlnError("usage: hello name")
}
```

## Os.environment

```ernest
Os.environment(name : String) : Optional(String)
```

*Since 0.2.0.*

The value of the program's environment variable `name`, or `None` where it
is not set. The environment is read once, when the program starts; where the
host gives a name twice, its first value is kept.

### Errors

Faults where the value is not UTF-8, with the cause `the environment
variable n is not UTF-8`, `n` the name.

### Examples

The editor the user chose, or `vi` where none is set:

```ernest
Optional.withDefault(Os.environment("EDITOR"), "vi")
```

## Os.user

```ernest
Os.user : Int
```

*Since 0.3.0.*

The host's number for the user the program runs as, bound when the program
starts. An `Fs.Entry` names the user a file belongs to by the same number.

### Examples

```ernest
Either.map(Fs.stat(Os.workingDirectory, 5000), fn(entry) = entry.user == Os.user)
```

## Os.workingDirectory

```ernest
Os.workingDirectory : Path
```

The absolute path of the directory the program was started in, bound when
the program starts, which nothing changes. A relative path given to `Fs`,
and a program's name to `start` that holds a `/`, `./tool`, are taken from
it; a name without `/` is looked for in `PATH`. A path joined to it is
absolute.

### Examples

```ernest
Os.workingDirectory <> Path("notes.txt")
```

## Os.exit

```ernest
Os.exit(status : Int) : a with m+
```

Ends the program with `status`, as the end of its entry process ends it, and
does not return. It ends the whole program, not one process; a process ends
by returning or by `kill` (report §8.6).

In the shell and under `ern test`, it faults the calling process with the
cause `exited with status n` instead, and ends neither.

### Errors

Faults where `status` is outside 0 to 255, with the cause `an exit status is
from 0 to 255`.

### Examples

```ernest
match Os.arguments {
    [] -> {
        Io.printlnError("usage: tool file...");
        Os.exit(2)
    }
  | files -> files
}
```

## Os.start

```ernest
Os.start(command : Command) : Either(Io.Error, Address(ProgramMsg)) with m+
```

Starts the program and answers its address, or `Left` with why it could not
start.

- `Left(NotFound)`: the program is not found.
- `Left(Denied)`: it may not be run.
- `Left(Invalid)`: a name or an argument no program could be given, one that
  holds U+0000 among them.
- `Left(Other(text))`: another reason, in the host's words.

The program reads `command.input`, then what `Os.write` gives it, until
`Os.closeInput` ends its input. It never reads the standard input of the
program that started it. It inherits that program's environment and working
directory.

It runs until it exits, until `kill` ends it, or until its owner dies: the
process that started it, or the one it was given to with `give`. Its owner's
death kills it, and with it the programs it started in turn that are still
in its Unix process group. To limit how long it runs, set a `Clock.alarm`
and `kill` it when the alarm comes; `Os.run` takes a limit of its own.

### Errors

Faults with the cause `the runtime's helper ern_exec failed` where
`ern_exec`, the small program the runtime starts others through, fails. That
is a fault of the installation, not of the command.

### Examples

```ernest
{
    let cat <-
        Os.start(Os.Command(program = "cat", arguments = [], input = String.toUtf8("hi")));
    Os.closeInput(cat);
    Os.read(cat, 5000)
}
// => Right(Stdout(<<104, 105>>))
```

## Os.read

```ernest
Os.read(program : Address(ProgramMsg), ms : Int) : Either(Io.Error, Output) with m+
```

The next piece of what the program wrote, to its standard output or its
standard error, in the order the host delivered them, and last its exit
status, once it has exited and both streams have ended. A status other than
0 is the program's answer, not a `Left`.

The host takes the program's output only while a read waits, so a program
that no one reads waits on its output. Where `ms` milliseconds pass first
the answer is `Left(Timeout)`, the program runs on, and what it writes
meanwhile is the next read's. The program's process ends once it has
answered the exit status.

### Errors

Faults where the program's process has ended, as it does once a read has
answered `Exited`: with the cause `callee had ended`, or `callee returned
without answering` where the call came as it ended.

### Examples

```ernest
{
    let sh <-
        Os.start(Os.Command(program = "sh",
                            arguments = ["-c", "echo no >&2; exit 1"],
                            input = <<>>));
    let first <- Os.read(sh, 5000);
    let last <- Os.read(sh, 5000);
    Right(#(first, last))
}
// => Right(#(Stderr(<<110, 111, 10>>), Exited(1)))
```

## Os.write

```ernest
Os.write(program : Address(ProgramMsg), bytes : Bytes, ms : Int) : Either(Io.Error, Unit) with m+
```

Gives `bytes` to the program as its input, after what it was given before.
It answers `Right(Unit)` once the program has taken them, waiting while the
program is behind, at most `ms` milliseconds; `Left(Timeout)` does not undo
the write.

A program that stops reading its input holds its writer, and one whose output
no one reads stops reading. So a program that both takes much input and
writes much output is written to by one process and read by another. Bytes
given after
`closeInput`, or once the program has closed its input or exited, are
dropped, and the answer is `Left(Closed)`.

### Errors

Faults where the runtime's helper fails, as `start` does. Faults where the
program's process has ended, as it does once a read has answered `Exited`:
with the cause `callee had ended`, or `callee returned without answering`
where the call came as it ended.

### Examples

```ernest
{
    let cat <- Os.start(Os.Command(program = "cat", arguments = [], input = <<>>));
    let _ <- Os.write(cat, String.toUtf8("hi"), 5000);
    Os.read(cat, 5000)
}
// => Right(Stdout(<<104, 105>>))
```

## Os.closeInput

```ernest
Os.closeInput(program : Address(ProgramMsg)) : Unit with m+
```

Ends the program's input, once what it was given before is written. A
program that reads to the end of its input then sees the end.

### Examples

```ernest
{
    let wc <- Os.start(Os.Command(program = "wc", arguments = ["-c"], input = <<1, 2>>));
    Os.closeInput(wc);
    Either.map(Os.read(wc, 5000), fn(output) = match output {
        Os.Stdout(bytes) -> String.trim(Optional.withDefault(String.fromUtf8(bytes), ""))
      | _ -> ""
    })
}
// => Right("2")
```

## Os.give

```ernest
Os.give(program : Address(ProgramMsg), owner : Process) : Unit with m+
```

*Since 0.2.0.*

Makes `owner` the program's owner, in place of the process that started it
or was given it before. The program is killed when its owner dies, and at
once where `owner` has already ended (report §6.9).

### Examples

A program started for another process to read, given to it, so that the
program is killed if its reader dies:

```ernest
{
    let program <- Os.start(Os.Command(program = "sleep", arguments = ["1"], input = <<>>));
    let reader = spawn(fn() : Unit with Never = match Os.read(program, 5000) {
        _ -> Unit
    });
    Os.give(program, Process.fromAddress(reader));
    Right(Unit)
}
```

## Os.run

```ernest
Os.run(command : Command, ms : Int) : Either(Io.Error, Finished) with m+
```

Runs the program to its end and answers its exit status and all it wrote: it
starts the program, ends its input after `command.input`, and reads it until
it has exited, within `ms` milliseconds of its start.

It answers `Left` where the program did not run to its end, as `start` and
`read` answer it: `Left(NotFound)`, `Left(Denied)`, `Left(Invalid)` or
`Left(Other(text))` where it could not start, and `Left(Timeout)` where the
milliseconds passed first, the program killed then.

### Errors

Faults where the runtime's helper fails, as `start` does.

### Examples

```ernest
Either.map(Os.run(Os.Command(program = "cat", arguments = [], input = String.toUtf8("hi")),
                  5000),
           fn(finished) = String.fromUtf8(finished.stdout))
// => Right(Some("hi"))
```

---

Generated by ern 0.3.1 from os.ern.

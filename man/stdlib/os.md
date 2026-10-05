# Ernest module Os

*Since 0.1.0.*

The host: the program's command line and environment, its exit status,
and the host's programs, run over Os's system process (report §8.2,
Appendix E.23). A running program is a process, as a `Tcp` socket is:
`start` answers its address, `read` answers what it wrote, piece by
piece, `write` and `closeInput` feed it, and `kill` and `monitor` work
on it as on any process. `run` runs a program to its end and answers
all it wrote. The program is found as the host finds a command, a name
without `/` in the directories of `PATH`, and each argument reaches it
as it is: no shell stands between, and a program that wants one runs
`sh` with `-c`.

## Examples

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

A program to run: its name, its arguments, and what it reads first as
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

A piece of what a running program wrote, to its standard output or to
its standard error, and last its exit status: 128 and the signal's
number for a program a signal ended.

### Examples

```ernest
match Os.Exited(0) {
    Os.Exited(status) -> status
  | _ -> -1
}
// => 0
```

## Os.Finished

```ernest
type Finished = Finished(status : Int, stdout : Bytes, stderr : Bytes)
```

How a program ended: its exit status, and all it wrote to its standard
output and to its standard error.

### Examples

```ernest
Os.Finished(status = 0, stdout = <<>>, stderr = <<>>).status
// => 0
```

## Os.ProgramMsg

```ernest
abstract type ProgramMsg
```

What a running program takes; a program uses `Os.read`, `Os.write`,
`Os.closeInput`, and `Os.give` (report Appendix E.23).

### Examples

```ernest
Os.start(Os.Command(program = "cat", arguments = [], input = <<>>))
```

## Os.arguments

```ernest
Os.arguments : List(String)
```

The words after the module on `ern run`'s command line, whatever they
look like, bound when the program starts; `ern run` refuses one that is
not UTF-8. In the shell and under `ern test` there are none.

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

The value of the program's environment variable of that name, or `None`
where the host has none. The environment is read once, when the program
starts, and a name the host gives twice keeps its first value.

### Errors

A value that is not UTF-8 faults the caller with `Fault("the environment
variable n is not UTF-8")`, `n` its name.

### Examples

```ernest
Os.environment("HOME")
```

## Os.user

```ernest
Os.user : Int
```

*Since 0.3.0.*

The host's number for the user the program runs as, bound when the
program starts. An entry of `Fs` names the user a file belongs to by
the same number (report Appendix E.17).

### Examples

```ernest
Either.map(Fs.stat(Os.workingDirectory, 5000), fn(entry) = entry.user == Os.user)
```

## Os.workingDirectory

```ernest
Os.workingDirectory : Path
```

The absolute path of the directory the program was started in, bound
when the program starts. Nothing changes it. A relative path given to
`Fs`, or as a program's name to `start`, is resolved against it, and
joining a path to it makes the path absolute.

### Examples

```ernest
Os.workingDirectory <> Path("notes.txt")
```

## Os.exit

```ernest
Os.exit(status : Int) : a with m+
```

Ends the program with that exit status, as the end of its entry process
ends it (report §8.6), and does not return. It ends the program, not a
process; a process ends by returning or by `kill`. In the shell and
under `ern test` it faults the process that calls it with
`exited with status n`, and ends neither.

### Errors

A status outside 0 to 255 faults the caller.

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

Starts the program and answers its address. The program reads `input`,
then what `Os.write` gives it, until `Os.closeInput` ends its input,
and never the standard input of the program that runs it; it inherits
that program's environment and working directory. It runs until it
exits, until its process is killed, or until its owner dies, the process
that started it or was given it (`give`), which kills it with the processes it started that are
still in its process group; a run is bounded as any process is, by an
alarm and `kill`. It answers `Left(NotFound)` when the program is not
found, `Left(Denied)` when it may not be run, `Left(Invalid)` for a
name or an argument no program could be given, and `Left(Other(text))`,
the host's reason, when it cannot start for another.

### Errors

Where the runtime's helper fails, the caller faults with `Fault("the
runtime's helper ern_exec failed")`, the runtime's own failure (report
§7.4).

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

The next piece of what the program wrote, to its standard output or to
its standard error, in the order the host delivered them, and last its
exit status, once it has exited and both have ended. The host takes the
program's output only while a read waits, so a program that no one
reads waits on its output. A status other than 0 is the program's
answer, not a `Left`. It answers `Left(Timeout)` when `ms` milliseconds
pass first, the program running on, and what the program writes meanwhile
is the next read's. The program's process ends once it has answered the
exit status.

### Errors

A read after the program's process has ended faults as
`Address.callForever` does.

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

Gives the bytes to the program as its input, after what it was given
before, and answers `Right(Unit)` once the program has taken them,
waiting while it is behind, at most `ms` milliseconds, and
`Left(Timeout)` when they pass first, which does not undo the write. A
program that stops reading its input, as one whose output no one reads
may, holds its writer; a program that both takes much input and writes
much output is written to by one process and read by another. Bytes
given after `Os.closeInput`, or once the program has closed its input or
has exited, are dropped, and the write answers `Left(Closed)`.

### Errors

Where the runtime's helper fails, the writer faults, as `Os.start`'s
caller does. A write after the program's process has ended
faults as `Address.callForever` does.

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

Ends the program's input once what it was given before is written.

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

Makes the process the program's owner, in place of the process that
called `Os.start` or was given it before: the program is killed when its
owner dies, and at once where the process has ended (report §6.9).

### Examples

```ernest
{
    let sleeper <- Os.start(Os.Command(program = "sleep", arguments = ["1"], input = <<>>));
    let keeper = spawn(fn() : Unit with Never = receive {
        after 1000 -> Unit
    });
    Os.give(sleeper, Process.fromAddress(keeper));
    kill(sleeper);
    Right(Unit)
}
```

## Os.run

```ernest
Os.run(command : Command, ms : Int) : Either(Io.Error, Finished) with m+
```

Runs the program to its end: starts it, ends its input after `input`,
and reads it until it has exited, within `ms` milliseconds of its start.
It answers the exit status and all the program wrote to its standard
output and to its standard error, or why it did not run to its end, as
`Os.start` and `Os.read` answer it: `Left(NotFound)`, `Left(Denied)`,
`Left(Invalid)`, `Left(Other(text))`, and `Left(Timeout)` when the
milliseconds pass first, the program killed then.

### Errors

Where the runtime's helper fails, the caller faults, as `Os.start`'s
does.

### Examples

```ernest
Either.map(Os.run(Os.Command(program = "cat", arguments = [], input = String.toUtf8("hi")),
                  5000),
           fn(finished) = String.fromUtf8(finished.stdout))
// => Right(Some("hi"))
```

---

Generated by ern 0.3.0 from os.ern.

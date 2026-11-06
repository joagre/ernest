# The blocks a bare shell cannot run

The blocks of the site's pages that a bare `ern shell` cannot run, each by its page's address and its first line, a transcript's by its first input. The site's generator gives each Copy alone, as the site's design says in *The live shell*. The test `test/ern_site_shell_tests.erl` pastes every block the site offers the shell, and every block listed here, into a bare shell, and holds this list equal to what it finds; `make site-unrunnable` writes it again.

- `/guide/1.html` `export fn main() : Unit =`
- `/guide/2.html` `let name = "Bob"`
- `/guide/8.html` `type Session = Arrived(Optional(Bytes)) | Ticked(Int)`
- `/man/stdlib/io.html` `match Io.read() {`
- `/man/stdlib/io.html` `match Io.readLine() {`
- `/man/stdlib/os.html` `match Os.arguments {`
- `/man/stdlib/os.html` `{`
- `/man/stdlib/terminal.html` `match Terminal.subscribe(fn(event) = event) {`
- `/why/` `type FirstMsg = Meet(Address(SecondMsg)) | AskFirst(Reply(Int))`
- `/why/` `type MainMsg = Done`

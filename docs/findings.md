# Findings of the release review

The findings of the review of the first release, run on 2026-09-30 as [`review.md`](review.md) says, on commit `691b4d6`: its machines, and its readers, the report's (R, the principles and the cold reader as one), a newcomer's (N), and the code's in three parts, over what changed since `0753fd8`: C1 the runtime and the standard library, C2 the front end, the checker and the emitter, C3 the command line, the shell and the libraries. M is a machine's. A line carries its decision: **tag**, fixed before the release's tag; **ask**, a question for the user, decided before the tag; **cheap**, clarity fixed before the tag where it is cheap; **2.99b**, planned in the plan's MVP 2.99b, its first item; **dropped**, with the reason; **next full review**, left for it. Each reader's list stands below the lines, condensed from what the reader handed in. This file goes when every line is done, dropped, or planned.

## Security

- ask — `Fs.removeAll` can be steered into another directory between its check and its listing (C1-3)
- ask — `Foreign.from` hands foreign code an address past its proxy (C1-4)

## Questions for the user

- ask — `Foreign` and a foreign type's equality (R-21)
- ask — `fn f` beside `let f = fn` (R-22)
- ask — the inferred restrictions are never written (R-23)
- ask — `via` runs its function in the sender (R-24)
- ask — `Os.start`'s milliseconds are a lifetime (R-25)
- ask — a local helper over an operator (R-26), and `Int.+`'s body that is not a call (R-27)
- ask — who owns a socket (C1-2), an address retyped by foreign code (C1-6), and `:load` of a compiled module unchecked (C3-9)
- ask — an alarm cannot be cancelled (N-C1), which the guide then says (N-B4), the order of a `Down` and the messages before it (N-B5), and `type Word = String` (N-C3)
- ask — the line the interrupt ends, kept in the history (C3-23)

## Hardening

- 2.99b — foreign code forging the runtime's handles (C1-5)
- 2.99b — the signals a started program inherits (C1-9), and the launcher's environment (C1-10)
- 2.99b — a temporary name, the configuration directory's window, startup files' owner, a crafted `.erc`, the shell's atoms, and `:output` to a pipe with no reader (C3-26 to C3-31)
- dropped — the proxies of distinct `via` addresses (C1-20): decided 2026-09-30, §8.4

## Where the language made the work harder

- dropped — decided before: a list of functions as a binding (C3-47, *A Cycle Through a Function Stays One*), `kill` on a `Process` (C1-39, *`kill` and `monitor` Keep the Address*), `Io.Error`'s text (C3-45, *`Other` Says the Host's Words*), an `if` without `else` (N-C4, N-L6), a `List` of `Reply` (C1-38, §6.6)
- 2.99b — the rest, each to [`language_feedback.md`](language_feedback.md) or dropped with its reason: C1-40 to C1-42, C3-41 to C3-44, C3-46, C3-48, N-C2, N-C5 to N-C8

## Rules that buy little

- next full review — the report reader's list of rules that buy little, and its counts (R's list below)

## The readers' lists

Each reader's list as it was handed in, condensed to a line a finding; the readers' programs are in the session's scratch directory, and each line names the file and line of `691b4d6`.

### R

Defects
R-1 E.1 vs §4.4: Io.show by static type breaks abstraction: fn show2(x) = Io.show(x) prints Seed(42) where Io.show(s) prints <abstract>; show2('a') 97.
R-2 §4.7/§7.4/§8.4 silent on a result type variable named by a parameter: foreign fn weird(x : a) : a = "erlang:length/1" returns 3 unchecked into List(Int); fault later in Io.show with host stack. Same for a callback parameter at a type variable.
R-3 §4.2 Prelude. escape: "Prelude.List.size is the prelude's List.size" but List.size is E.2's; reaches List.size past local type List but not Io.println past local type Io; a root module's function unreachable from a module whose type shares its name; toolchain refuses Stack.other that §4.2 resolves to the root module.
R-4 §3.9 vs §4.6: "a binding that is not generalized whose type keeps a variable nothing resolves" asks annotation; block lets not generalized but §4.6's { let xs = []; List.size(xs) } stays open. Fix: "a top-level binding".
R-5 §5.10 "as binds loosest" vs Appendix A (or looser than as): Some(1) or Some(2) as x refused; patterns can't be parenthesized.
R-6 E.0 rule 4 vs the listing and rule 2: Map.merge, Map.contains, List.any, String/Bytes.contains, Set.union/intersection/difference/isSubset, Map.keys/values, Io.println are compositions.
R-7 §7.3 says causes are §7.4's; E.22's four causes not in §7.4.
R-8 E.1 "<reply>" cannot happen (Io.show is (a!) -> String).
R-9 E.0 shape rule 5 vs Supervisor.group with m (spawns, reaches no system reference): add "or spawns".
R-10 E.0 shape rule 8's kinds omit Clock.monotonic and Io.debug.
R-11 §3.10 omits Foreign in "instantiating it with a type that contains a function or an address".
R-12 §5.7 vs Appendix A: x |> Some(1) and x |> W(b = 2) unsettled; toolchain treats them differently.
R-13 §5.11: <<256>> and <<-1>> compile (fault at run time) but <<1:size(4)>> refused; which violations are compile-time.
R-14 §6.9/E.22: a sibling that never waits blocks the faulted child forever; not stated.
R-15 §6.9 "whichever run asked": restarting entered partway (monitor before restarting) — cancelled? say "before or within a run".
R-16 §11.8 no status for ern run ended by the host's interrupt.
R-17 §8.2 order of checks: stdin not a terminal, a line read, then Terminal.subscribe: NotATerminal or "already read as lines"?
R-18 §11 refuses old spellings it never lists.
R-19 §11.4 ern doc's usage line omits file.erc and src-dir forms (SYNOPSIS).
R-20 E.1/E.3 Io.show of a Map has no fixed order: // => examples nondeterministic.
R-21 §3.7/§3.10 vs §3.8: Foreign and a foreign type differ in equality.
R-22 §4.5/§4.6 two ways to declare a function (fn f vs let f = fn), differ (recursion).
R-23 §3.9 inferred restrictions never written; exported signatures don't show process-only/equality/reply.
R-24 §6.5 send through via runs hidden code in the sender; a fault in f kills the target.
R-25 E.23 Os.start's ms is a lifetime, not a wait (shape rule 8).
R-26 §4.8 a local helper over an operator needs an annotation (fn add(a, b) = a + b inside a body).
R-27 §9.6 fn Int.+(a, b) = a + b "not a recursive call": declare as foreign fn shims.
Clarity
R-C1 §3.9 uses a! before §11.5 defines it. R-C2 §8.4 "and so is one Ernest code gives to a Reply foreign code gave" unclear. R-C3 §6.6 "callee was restarted where its supervisor restarted it" -> where a restart was asked for. R-C4 §6.9 "a process that computes without waiting is not restarted" reads as never. R-C5 §6.9 "begins with nothing of the old one" but children, sockets, programs, tables survive. R-C6 §8.2/E.21 "one subscription" -> one of each kind. R-C7 §8.5 "in the order §8.5 evaluates them" self-reference. R-C8 §5.4 cites §4.6 for let _, should be §5.10. R-C9 §4.4 external names omit Main.Stack.pop/empty. R-C10 §3.7 lacks Process. R-C11 E.0 rule 1 "the cause of a restart" undefined. R-C12 E.17 Left(Other("exists")) vs Fs.Kind's Other. R-C13 §11.2 --source-root dir vs §11.7 src-root. R-C14 §11.2 ./.ernest/startup not run without --config-dir though ./.ernest is default. R-C15 E.18 site "Tcp.listen" without line. R-C16 Appendix F gaps/order/stale entries. R-C17 G.1 "abridged" but D shows all nine.
Rules that buy little: private abstract type error; lambda-let generalized; "not a recursive call"; Prelude.; reply linearity machinery; type-directed Io.show; Test/TestResult in prelude; result type variable taken as Unit; §6.7 restates §6.2; ////; Path.toString and Map.merge; reserved abstract/export/foreign could be contextual; k= only in foreign type; guard-expression language. Keep spawnMonitored, callForever modest.
Counts: reserved 18 (18); contextual 11 (12, or 12 with Prelude); namespaces 35 by old method / 25 by §4.2 now; prelude functions 30 (32: §9.6 19 was 21); prelude types 25; primitives outside §9 3 (5-6 counted the same way now); concepts 89 (79; Appendix F 100 entries).
Toolchain divergences: Stack.other not resolved to root module; no `a < -1` help inside a block (§11.5); follow-on "operand type not determined" error reported (§11.5 says not).

### N

A. Defects
A1 guide §2.9 l533: Io.show example Other("eaddrinuse") now "address already in use" (stale after E-C5).
A2 guide §1.4 l244 "(b) with `-> Unit`" and §2.4 l366 "function result types use `->`": a result is `: T`.
A3 §8.1 square.ern: peers fault "peer unreachable"; nothing says peers unbuilt; `ern config` writes config nothing reads; "MVP 3.0" meaningless to newcomer.
A4 §4.4 l904 fan-out cites §8.7 for member/writer/credit (§8.7 is echo server); §9.5 systemd unit for "the chat server" never built.
A5 §2.5 l400 address-as-map-key error underlines Map.size/Map.get/Map.empty, never the key.
A6 guide l3 "needs nothing beside it" vs pointers to style.md, development.md, Appendix C, libs/ets load path.
A7 §8.4 l1938 Ets.new/put "a function §8.5 builds": §8.5 builds only get.
B. Clarity
B1 README counter example unexplained (with Never, Local, Reply/answer, 1000 ms).
B2 README leads with distribution (unbuilt); name the release.
B3 README: minimum OTP version.
B4 guide: alarms cannot be cancelled not said in §5.5.
B5 order between Down and a process's earlier messages unstated (§5.2).
B6 fault-line timestamps when stderr piped: note at §6.3.
B7 error "NotText has named fields; write NotText(field = p, ...)" should name the field.
B8 shell: `let w : Word = "x"` says "body ... declared to return Word": wrong words for a let.
B9 :doc Fs.Entry "milliseconds ... a whole number of seconds" reads as contradiction.
B10 :browse Fs shows `type Fs.Entry` without fields; :browse not mentioned at §2.9.
B11 §7.2 Stack.push(x, stack) breaks subject-first.
B12 §14 l2276 "paper programs" unexplained.
B13 ern format: `if` inside a lambda laid out awkwardly (else under lambda start).
C. Language made it harder
C1 alarms can't be cancelled; deadline messages pile up in a long-lived coordinator (queued grows one per job).
C2 no stated order between Down and messages.
C3 `type Word = String` declares a new type with a nullary constructor String shadowing prelude name; no warning; no alias.
C4 no one-armed if.
C5 no string formatting.
C6 four near-identical match arms (Map.get in receive guards impossible).
C7 String.split literal separator only.
C8 nested record updates spell both constructors.
Program: /home/jocke/.claude/jobs/0fab4189/tmp/review/newcomer/findex/findex.ern

### C1

A. Security exposures
C1-1 ern_tcp.erl:95-98 guarded catches only error: ; host with U+0000 -> gen_tcp exit:badarg, worker dies, caller hangs, deadlock detection stops. Refuse U+0000 in host (E.18), catch every class.
C1-2 ern_tcp:45-49 socket outlives the handler that faulted (linked only to Tcp): fd/process leak per connection. E.18 says so literally -> report question: a socket killed when the process that opened it dies (E.23's rule).
C1-3 fs.ern:306-331 removeAll TOCTOU (readLink, stat, list) -> symlink swap empties another dir (CVE-2022-21658). Fix in ern_fs with lstat before each list, or state the race.
C1-4 §8.4 checks skipped: Foreign.from carries an address past the proxy; function nested in argument/message/answer not wrapped (=C2-7); foreign answer to a stdlib call not checked (standard mode).
B. Hardening
C1-5 ern_boundary:170 chk pid accepts forged {via,F,T}/{foreign,...}/{foreign_reply,...} from foreign code; foreign `R ! {R, answered, V}` skips the check.
C1-6 ern_rt:127-133 held/3 undoes a proxy without comparing descriptors: Address(Int) handed back as Address(String) delivers unchecked. Report question.
C1-7 fresh_run waits for {Ref, fresh} with no monitor: a dead clock/terminal holds every restart forever.
C1-8 settled/1 flushes only one stray answer.
C1-9 ern_exec.c:202-207 children inherit ignored SIGFPE; reset all catchable signals.
C1-10 Os.environment carries the launcher's BINDIR, EMU, PROGNAME, ROOTDIR.
C. Defects
C1-11 supervisor: A faults, B asked; B faults on its own before taking the ask; emptied() drains the ask; B restarts AfterFault, no Settled(B); A waits forever. Fix: Faulted(p) -> settled(waiting, p).
C1-12 held/3: a via address round-tripped through foreign code loses its function (behind row holds process_of). Type-unsound delivery.
C1-13 ern_boundary raised/6: '$ern_restart' thrown in a callback foreign code runs becomes a fault. Let it through.
C1-14 String.split/lines/replace quadratic (parts re-measures). Predates.
C1-15 ern_exec.c:335-339 memmove per partial write: quadratic stdin to started program.
C1-16 supervisor watcher releases held child on Run before askRestart: child runs f twice.
C1-17 supervisor counted: callForever(sup, Faulted) -> a child waiting when the supervisor restarts in place gets Fault("callee was restarted"), reported/counted. Use Address.call + Process.info.
C1-18 second process running a group after first supervisor died: "callee had ended" not "a group runs in one process"; a supervisor killed before Run lets the next become supervisor silently.
C1-19 child joined but not yet in restarting: ask_restart does nothing but counted as asked -> faulted child hangs. askRestart answers Bool, filter.
C1-20 proxies accumulate per distinct via (decided §8.4) — noted.
C1-21 restart scans: restarted/1 ets_match(?CALLS) over all calls (was ets:take on callee bag at 0753fd8); cancelled/1 ets:match over ?HELD in reaper and clock; three round trips per restart. Against CLAUDE.md cost rule.
C1-22 ern_rt:1395-1398 {fault, Msg, Trace} in an initializer not reported under the binding.
C1-23 supervisor.ern:10-11 page says mailbox kept; :20-21 "not when it restarts because it was asked" vs Settled sent then.
C1-24 Tcp.connect can't reach IPv6 (no family).
C1-25 Fs.readRange with huge count allocates: Other("not enough memory"/"invalid argument"); E.17 promises fewer bytes or none. Cap count.
C1-26 Os.start: argument > 128 KiB -> "the runtime's helper ern_exec failed" (E2BIG status 7 before s).
C1-27 Foreign.toList accepts improper list.
C1-28 ern_os:145-149 stop/1 leaves the deadline timer; stale {timeout, Ref} makes quiet/1 read busy (deadlock detection).
C1-29 Path: extension(Path("..")) = Some(""); withExtension(Path("a/.."), "") = "a/."; withExtension/join normalize "a//b".
C1-30 String.isEmpty O(n); E.20 promises Bytes.lastIndexOf, missing; Clock.monotonic `with m` vs E.0 rule 5.
C1-31 page examples without // => (process.ern:43, terminal.ern:33,113,213,222); bytes_test covers none of 10 new functions; restart_ends_subscription_test ignores subscribe result.
D. Clarity
C1-32 supervisor run numbering now dead (clock cancels alarms at restart): Group.run, Expired(Int), runs counter, Run's Optional(Int).
C1-33 ern_rt comments: HELD comment omits delivering rows; :14-15 answered form "as §8.4 says"; :444 dead `_ -> ok`; ets_match name.
C1-34 ern_tty_tests silent/0 comment misplaced; Makefile -pa comment merged into PARTS paragraph.
C1-35 supervisor: counted recomputes fromAddress(me); Msg doc "what it sends itself"; group's "one process runs it" ambiguous; child's Errors "a child runs on its supervisor's node" unreachable.
C1-36 ern_boundary header omits {callback, Make}; check/3 comment; ern_tcp:219-222 stacked comments; ern_os:83 history; guarded name clash; armed/zeroed walk whole descriptor per value.
C1-37 pages: Map/Set signatures without k=/a=; Set.toList order; Path.name(Path("/")) = ""; Process.live "started" omits adopted; io.ern:33 and/or; bytes.ern wording; terminal.ern:266 two lookups; ern_show:169 comment \\n.
E. Language harder
C1-38 List cannot hold a Reply -> Held/Waiting hand-rolled.
C1-39 kill/monitor take Address(a) -> closures (decided E-C2).
C1-40 a process cannot wait without a message of its own type -> Hold call.
C1-41 Strings: no position carried; slice has no "to the end".
C1-42 Int.toStringBase Optional for literal base; no List.findMap; bitstring pattern can't compare a segment with a bound value.

### C2

A. Defects
C2-1 emitter ern_emitter.erl:545,611 swaps a module's own Io.show/Io.debug (type Io + fn Io.show) for the stdlib's: matches the written path, not the checker's ref.
C2-2 emitter :271 Unnamed = type_vars(Ret) -- ...: `--` removes one copy; foreign fn pair(n : Int, x : a) : #(a, a) faults on every return ({tuple,[never,never]}).
C2-3 typecheck :2788 `fn f(x as x) = x` / `#(a, b) as a` crashes (exit 70): p_as names not walked.
C2-4 parser :479-482 regression: shell no longer takes another line after `if c then a` (error at `if`, not eof → not incomplete). Also older: `fn f(g : ()` at eof not incomplete.
C2-5 parser :826-827 pattern `-0.0` is host negative zero: never matches; `0.0 | -0.0` not redundant (§3.1 no negative zero).
C2-6 emitter :257-266 fault inside an Ernest callback called by foreign code reported as "foreign function lists:foreach/2 raised error:badarith" instead of Fault("division by zero") (§7.4).
C2-7 emitter exposed/2 :940-950 + crosses/1 :1044: a function nested in a foreign argument (#(Int, (Int) -> Int)) not wrapped (§8.4 requires the check).
C2-8 typecheck :1377 impl name regex `$` accepts trailing "\n": "erlang:abs/1\n" builds.
C2-9 typecheck :1203,:1211-1216 init-cycle message names member let without its type (`empty` not `Stack.empty`).
C2-10 typecheck :1209-1212 cycle help for lambda-valued let with Others≠[] suggests `fn f() = ...` which changes f's type; give `fn f(...) = ...` whenever Body is a lambda.
C2-11 typecheck :1198,:1209 "through" list usorted (not cycle order); help names wrong function (f vs g that reads a).
C2-12 `fn k(g) = { let _ = g == g; g(1) }` equality error reported at g(1), not at ==.
C2-13 ern_diag.erl:81 lone CR dropped in excerpt while lexer counts a column: caret off by one; should show U+240D.
C2-14 parser help lines false: `x : ()` "the type of no value is Unit"; `x : Io.println` "type arguments are written Io(println)"; `type _p` "...: _p" unchanged; `Circle()` with fields "written without them".
C2-15 ern_types.erl:455 signature help uses `->` for zero-param/pattern-param heads, `:` otherwise.
C2-16 formatter trailing/3 ern_format.erl:731-735 adds a space after an opening bracket before a block comment: `g( /* a */ 1, ...)`.
C2-17 (unverified) emitter :398-403 a match's size-let reads run before its scrutinee (§5.11 "when the match begins" after scrutinee §5.1).
B. Clarity/specs/comments
- ern_emitter :1250 stale comment above pattern_names/1; :1436 unreachable clause {{named,Names},none}; :120 use #scheme record; :1521 + ern_bitspec :20 unit key now only 8/1.
- typecheck :3187 -spec prelude_one separated from its function; :632 filter N =/= none never false; :1897 declared_scheme/3 catches only {type_error,_,_} (lookup_value throws {type_error,#diag{}}) -> catch throw:_; :1149-1186 reference_graph built twice; declared_twice/first_repeat/twice quadratic.
- parser :418 help deep list vs fail/3 spec string(); :964 through/3 placement.
- ern_prelude :455 restarting's "### Errors" untrue under Unlimited, doc never mentions Unlimited; :608 comment cites "(plan, MVP 2.5)".
- ern_pretty :216-219 accept/3 comment omits `alternative`; header "style guide" vs §11.6.
- ern_format :342-344 confusing comment about the parameters' bracket.
Conforming: == on function types; one-constructor type formatting; lexer control chars; `...` gap; standard mode; RestartLimit/Unlimited.

### C3

Options match §11.7 exactly; conforming statuses: --help/--version 0, refused command line 1, format --check 1, ern test 1, ern run Os.exit, killed entry 1, closed stdout 141 via ern_out.
Security
C3-1 shell.ern:476, :492 an input's own fault cause and a report cause written raw ("fault: " <> text): control chars reach the terminal; §11.2 says escaped.
C3-2 editor.ern:165 pasted text and C1 typed chars inserted raw; region paints them: OSC reaches terminal (title/clipboard), cursor miscounted, history replays. Paint controls as pictures.
Defects
C3-3 ern_shell:1342 with_sources catches only throws; parse_module {ok,Bin}=file:read_file: :load of unreadable/0xFF source ends the whole session (status 1). Also :1593, :1716, compiled_of :1739.
C3-4 I/O errors exit 70 (ern_build :112,:278,:422,:433; ern_cli :403,:432,:507,:617,:1001,:1047): unreadable source, build-root in /proc, config in ro dir. §11.8 says 1.
C3-5 non-UTF-8 source crashes (70) in ern_diag:lines via report_errors/error_text; --short-errors gives 1.
C3-6 ern_build:194,:202 re:run without unicode: path component outside Latin-1 crashes (70); shell completion of such a dir kills the reader. No regex (CLAUDE.md).
C3-7 ern config --config-dir dir/ creates dir then refuses it (eexist), leaves it.
C3-8 ern shell with stdout closed exits 0 with host error report; §11/§11.8 say 141.
C3-9 :load of a compiled module skips interface/stdlib checks (needed_one, compiled_of) vs ern run's; report silent.
C3-10 startup file's :load/:reload/:type diagnostics lose file and line (§11.2).
C3-11 editor.ern:147-151 Delete/Home/End/PgUp/PgDn/F1-F4/Ctrl-arrows insert characters ("a3~", "aH"); §11.2 every other control key does nothing.
C3-12 ern format dir takes dir as source root: namespace rules refuse valid modules (util/list.ern "takes the prelude namespace List").
C3-13 ern run/test/shell of a non-Ernest .erc prints the binary (438 KB) instead of "x.erc is not a compiled module".
C3-14 --main not checked: 300 A's -> system_limit (70); ../../etc.main looks outside the load path; A..b.
C3-15 ern_build:119-120 nested non-UTF-8 names crash (70) instead of §11.1's error.
C3-16 ern_build:628 doc sweep list_to_atom of a page's title: 300 A's -> system_limit (70); unreadable page crashes.
C3-17 ern_cli:894 ern test writes a test's name raw (controls).
C3-18 ern_cli:809,:814 the shell's own session fault exits 1 (§11.8 says 70); Msg unescaped.
C3-19 (unverified) reload end_previous exits then purges without waiting: processes may end Killed rather than Fault("its code was unloaded").
C3-20 :load List answers as success (plain), §11.2 says refused (red).
C3-21 :type let _ = 1 accepted, :type let x = 1 refused.
C3-22 history.ern:55-57 two shells trimming share history.new.
C3-23 report silent on whether C-c keeps the line in history; code keeps it.
C3-24 shell/README.md:75 run/3 (is run/4); :69 "only Shell.Editor uses another" (Complete uses Command).
Hardening
C3-25 ern_build:741 write_whole follows a .erc link planted in the build tree (overwrites the link's target).
C3-26 ern_build:751-761 predictable temp name, not exclusive: planted link truncates victim's file in a shared dir.
C3-27 ern_cli:1048-1049 config dir made then chmod 700: window; key file not exclusive/600 at creation.
C3-28 startup files run without owner/mode check.
C3-29 binary_to_term without [safe] on .erc chunks (ern_iface:37, ern_docs:23); ern_page:81-83 source name into roff comment unescaped.
C3-30 ern_shell:805 binary_to_atom from :doc/:forget/:browse/:load/Shift-Tab; lexer on every Tab: atoms grow.
C3-31 :output to a FIFO without reader blocks the session.
Clarity
C3-32 no_job/1 repeats old_spelling/1 messages. C3-33 ern_build header claims other jobs out of compiler hash (false). C3-34 orphan comment ern_cli_tests:307. C3-35 shell obey 8 copies of refuse; Continue. C3-36 editor names back/from/step double meanings. C3-37 complete.ern repeats. C3-38 history made per append (two fs requests per input). C3-39 persistent_term replaced per input/test (global GC). C3-40 Markdown.roff(page, blocks) subject second.
Language harder
C3-41 no library fn writes a string's controls as escapes. C3-42 grapheme vs Char predicates. C3-43 Int.toStringBase Optional. C3-44 every local-file call needs a timeout. C3-45 Io.Error has no text. C3-46 exhaustive match on String.split forces [] arm. C3-47 list of functions as let (E-C1). C3-48 shim answering true needs raw fn + wrapper.


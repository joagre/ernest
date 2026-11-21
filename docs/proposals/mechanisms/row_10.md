# Row 10: the check with no process

Status: decided with the user on 2026-11-21 that the checker goes, on one condition: the sentences below are read cold first, and where they grow exceptions of their own the checker stays. They were read the same day, and they do: *The cold reading* has what it found. Recommended since: the checker stays. The user's word is waited for. Nothing here is in the report.

[`first_five.md`](first_five.md) has why, and what a program loses.

## The cold reading

A reader was given the report with the sentences applied, and neither the log nor this file. It found two holes that are the form's own, and a dozen sentences the draft lacks.

- **A handle reaches Ernest code, and nothing says what it is there.** A type variable in a call's answer type matches any reply (§8.4). A program sends `Put(self())` to a foreign registry of type `Address(Request(Address(Event)))`, so its address crosses as a handle, and asks for it back through `fn ask(server : Address(Request(a))) : Optional(a)`. The answer is the handle, unchecked, with no promise broken, and the program's `send` meets a term that is no process. A return at a parameter's variable and a delivery by host identity are two more ways. So a handle must be an address to Ernest code: a fourth shape that every `send`, call, `adapted`, monitor and crossing to a peer takes. Today the check's address is a process, and each works.
- **A handle is dead on another node, and an ordinary `send` puts it there.** A foreign address may name an Erlang process on node a. A program on node b sends it `Subscribe(self())`. The address crosses on b, where the `send` is, and the Erlang process on a then sends through a handle whose type's row is on b. It raises. Today the pid leads back to b. The form closes it only by a check that runs on a node that may not hold the type, or by a frame to b and something there that checks, which is a process again.
- **An adapted address's function in a foreign sender.** What it opens is the foreign process's, a restart in it is not refused (§6.9 refuses one "on delivery" alone), and one that never finishes holds that process. Closed by applying it in the process kept for the address (§6.5), which brings back the step more for an adapted address.
- **What the draft does not say, each a sentence more:** whether two handles of one address are equal, which a library that unsubscribes needs; what the function answers for a bad message and for an ended process; that foreign code makes and alters no handle, a promise more in `docs/soundness.md`; an address in the result of an Ernest function foreign code calls, which goes raw today, so that foreign code would hold two kinds; an address given to the standard library; a raw address given back at an address type; and that foreign code can no longer learn that the process behind an address ended.

**Against the condition.** The 98 words the draft saves are spent by these sentences, and the first two holes are answered by a narrower promise or a new mechanism, not by a sentence. A pid is the one value the host's world already sends to, compares, monitors and carries between nodes, and Ernest's own `send` takes it. A handle has each of those made for it again.

**Recommended:** the checker stays (principle 1: a reader who knows Erlang's processes is given a process). MVP 4.5's items 113, 149 and 153 stand, and the two suspicions of [`first_five.md`](first_five.md) on a checker's pid join item 149.

The rest of this file is the draft as it was read.

## The form

- **A handle.** An address that crosses into foreign code crosses as a handle: a term of the runtime's that holds the node it crossed on, the address, and the hash of the type it crossed at. It is no process of the host's.
- **One function.** Foreign code sends through `ern_foreign:send(Handle, Message)`, which answers `ok`. It checks the message against the type the handle names, in the process that calls it, and then sends as `send` does. A message that does not match is not sent, and the receiver is sent the fault as today.
- **One table.** A row for each type an address has crossed at, the hash with what the check needs, written at the first crossing and kept while the runtime runs. So a handle holds no function of a unit, and two crossings of one address at one type give equal terms.
- **Where it raises.** On another node than the one the address crossed on, and for anything that is no handle, the function raises `error:badarg`. A handle of an ended run names an ended process, and what is sent through it is dropped as any message to one is (§6.2).
- **What is gone.** The checker, the lookout, the table of checkers, the reaper's holding of them, and the look's read of them.

## The sentences

Each sentence the report loses, gains or changes. A section not named keeps its text.

### §8.4, its first paragraph

"a bad return value or reply when the call returns, a bad message on delivery" becomes "a bad return value or reply when the call returns, a bad message when it is sent".

### §8.4, **Addresses and answers**, as it would read

**Addresses and answers.** An address that foreign code gives, in a return, a reply, a message, or an argument it calls an Ernest function with, is *foreign* unless it names a process of the program. An address of the program's that foreign code gives back is the program's own at the type it crossed at, and foreign at any other. What is sent to it at another type is checked as a message foreign code sends. A type is the type an address crossed at where the two have one hash (§8.7) once every type variable in each is written as the same variable.

A process of the program's whose address foreign code was never given, one it names by its own `self()` in a `foreign fn` or by a `Process` it was given, is a bad value where foreign code gives it as an address, except as an `Address(Never)`, through which no message passes.

A message sent to a foreign address, an answer given to a `Reply` foreign code gave, and a foreign function's argument cross into foreign code. An address in one crosses as a *handle*, which names the address and the type it crossed at, and is no process of the host's. Foreign code sends to the address through the handle, by the runtime's function (§12.2), and the message is checked against that type when it is sent, in the process that sends it. A message that does not match is not sent. A handle sends on the node where its address crossed, and on another the function raises. A foreign address goes back as foreign code gave it.

A message foreign code sends to an adapted address is checked against the type the address crossed at before its function is applied. The message then goes as a `send` of it goes (§6.5): where the address was made on that node, its function is applied in the process foreign code runs in.

Foreign code sends as the process it runs in, the calling process or a foreign process, and what it sends keeps its order as any sender's does (§6.4).

A bad message's fault goes straight to the receiver. It can pass a message foreign code sent before it through an adapted address made on another node, which takes the one step more of §6.5. A receiver that is a foreign process the runtime did not start takes the fault as such a target takes a fault in `f` (§6.5).

An answer foreign code gives to a call is checked when `Address.call` or `Address.callForever` returns it. An answer Ernest code gives to a `Reply` foreign code gave crosses into foreign code, and no other answer is checked.

### §8.4, **Functions**

"an address in it behind its check and a function with its own" becomes "an address in it as its handle and a function with its check".

### §8.4, **Type variables**

"an address in it has no check, and a function no check of its arguments" becomes "an address in it crosses with no handle, and a function with no check of its arguments".

### §6.4

"So can a message that goes through a check (§8.4)." goes.

### §8.7, **Messages**

"but for the one step more of §6.5 and that of a check (§8.4)" becomes "but for the one step more of §6.5".

### §10

The bullet on a check of what foreign code sends becomes: "A check of what foreign code sends to an address (§8.4) costs a walk of the message, in the process that sends it, and a row for each type an address has crossed at, kept while the runtime runs."

### §12.2

After "`Address(m)`, function values → opaque handles foreign code may pass back but not inspect." a line is added: "An address's handle is no process of the host's: foreign code sends `v` to it by `ern_foreign:send(Handle, v)`, which answers `ok`, and which raises `error:badarg` for a term that is no handle and on another node than the one the address crossed on (§8.4). An address at a type variable crosses as the runtime holds it (§8.4)."

### §12.3

"A message from a foreign process that does not match the type its address crossed at, `M`, faults the receiver on delivery (§8.4)" becomes "A message foreign code sends through a handle that does not match the type its address crossed at, `M`, faults the receiver (§8.4)".

"`M` is printed as the module whose crossing made the check prints it" becomes "`M` is printed as the module of the first crossing prints it".

### Appendix D

"The report states none of the runtime's functions" becomes "The report states one of the runtime's functions, the one foreign code sends through (§12.2), and no other".

### Appendix E.21

"through every adapted address and every check (§8.4)" becomes "through every adapted address".

### Appendix F

**foreign address** becomes: "an address foreign code gave that names no process of the program, to which what is sent crosses into foreign code; or one of the program's given back at another type than it crossed at, to which what is sent is checked. §8.4." A new entry: "**handle** — what an address crosses into foreign code as: it names the address and the type it crossed at, is no process of the host's, and is sent through by the runtime's function. §8.4, §12.2."

### The count

The report loses 98 words net: about 370 go and about 270 come. It loses the exception to §6.4's order, the check's life, a different address for each check, and the message not yet in the mailbox when the foreign function has returned.

## The argument, `docs/soundness.md`

- **Section 2**, a bullet before the one on a message that fails the check: "An address crosses into foreign code as a handle that is no process of the host's (§8.4, §12.2). So foreign code reaches the mailbox behind it through the runtime's function, which checks, or by a host identity it holds, which its fourth promise covers."
- **Section 2**, the fourth promise: "which no check on delivery could see" becomes "which no check could see".
- **Section 5**, twice: "a message from foreign code is checked on delivery (§8.4)" becomes "a message foreign code sends through a handle is checked when it is sent (§8.4)".

No other paragraph changes: a fault still stands in a mailbox in a bad message's place, and an address given back is still the program's own by the type's hash.

## To decide with the user

- **The function's name**, `ern_foreign:send/2`. `ern_foreign` holds `Foreign`'s shims today.
- **A handle on another node raises.** The other answer is a drop, as a message to an address of an earlier start is dropped (§8.7). A raise is said, in foreign code's own process.

## What follows a yes

The report and `docs/soundness.md` first, then the log, then the build: the runtime, the emitter's descriptors, the tests of the checker, the design notes' lines on the checkers and the look, and the guide's two sentences on order and on a message checked on delivery. MVP 4.5's item 113 goes, and items 149 and 153 are read again.

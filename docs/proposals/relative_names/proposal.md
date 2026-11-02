# Relative names

A proposal for §4.2. Written 2026-11-02; decided with the user before the report changes,
and built after the cold reading §3 to §9 ask.

## The need

A module names another by its full qualified name, wherever the two stand: `Ernest.Shell`
names its child as `Ernest.Shell.Command.parse`, and `Ernest.Shell.Complete` names its
sibling's constructor as `Ernest.Shell.Region.Region`, 139 sites in the shell, each a
sentence about where the module stands before it says what it does. The shell is not
special: `Fides.Officer.Tally` names `Fides.Officer.Ballot.count` the same way, and the
deeper the tree the longer the names. §4.2 has no import and no alias, by design.

## The rule

A qualified name resolves from the writer's namespace outward. Its first segment is looked
up as a child of the writer's own namespace, then of its parent, and so on to the root,
whose children are the root modules, the prelude's namespaces and the standard library's;
the rest of the name descends from where the first segment was found. So `Command.parse` in
`Ernest.Shell` names `Ernest.Shell.Command.parse`, `Region.Region` in `Ernest.Shell.Complete`
names its sibling's, `Shell.attach` in `Ernest.Shell.Complete` names its parent's, and
`Io.println` anywhere names the library's. A first segment found nowhere is an error, as a
module that does not exist is today.

The shortest resolving form is the only form: a name written longer than it, `Ernest.Shell.Command.parse`
where `Command.parse` resolves, is an error whose help names the short one, as §4.2 already
holds `Prelude.x` to be an error where the plain `x` is the prelude's. A reader then reads
every name as a relative path from the file's place, which a reader of any tree of files
does already, and a name is written one way.

## The questions

**A module that hides a root name from its own family.** A program's `fides/io.ern` is
`Fides.Io` today, allowed by §4.2 since it neither coincides with `Io` nor stands under it.
Under the rule, `Io.println` written anywhere under `Fides` would resolve to `Fides.Io`, and
the library's `Io` would be out of reach from there, since no longer form is allowed and no
form says "from the root". Two ways: let it shadow, as a `let` shadows, and give the root a
spelling of its own; or take the name at every depth, so that no module is named as the
prelude or the standard library names one, `fides/io.ern` refused as `io.ern` is. The
recommendation is the second: a module that hides the language's own words from its family
is a trap no program wants (principle 1), a root spelling is a second form (principle 2), and
what a program loses is a handful of names, `Test`, `Clock`, `Process` among them, which
`ern build` names in its refusal. A library of the toolchain's own (Appendix G) stays
untaken, as §4.2 has it: a program's `Fides.Http` hides `Http` for its family, which is what
hiding a library means today.

**How far a short name reaches.** Only the first segment climbs; the rest descends. So a
cousin is reached through the nearest common ancestor's child, `Shell.Command.parse` from
`Ernest.Other`, and nothing is reached by a path that skips a segment. The recommendation is
this rule as stated, C++'s, and no search by suffix as Unison does, since a suffix names a
place only once the reader knows the whole tree.

**Two modules a first segment could name.** The nearer wins, as the inner `let` wins, and
the farther is out of reach from there by the question above. A module added later can
change what a name in a neighbor means; the compiler then reports the neighbor's name as
resolving elsewhere, or as too long, at the next build.

**What prints.** A diagnostic, `ern doc`, `:browse`, a fault's trace and a process's site
print the full name, as today: a reader of a trace has no place to read a relative name
from. The one exception is the help of the too-long-name error, which names the short form
from the writer's place.

**The dependency scan.** `ern build` finds a module's dependencies by the qualified names in
its source (§11.1), and so must resolve each against the modules it can see, the source root's
and the load path's; a `.erc` records the full names, as it does. The shell's `:load` resolves
the same way against the session's modules.

## What does not change

Appendix A's grammar, since a qualified name is the same token sequence. Appendix H's canonical
form, which keeps full names, so no hash moves and no exchange between nodes changes.
`ern format`, which lays names out and does not resolve them. §11.1's path rule and the
taken namespaces of the prelude and the library at the root. A session's inputs, which stand
at the root and name every module as today.

## The cost

The checker and the build's scan look a first segment up in at most as many namespaces as
the writer has ancestors, a map lookup each, beside the one lookup made today; the build's
timing shows it, and `make bench` is not touched. The toolchain pays once: the shell's 139
sites are written short in the same item.

## The build order

1. §4.2's three sentences, the taken-at-depth rule beside them, Appendix F's line for a
   relative name, and the log's entry; the cold reading before the code.
2. The checker's resolution and the too-long-name error, with its help; `make diagnostics`.
3. `ern build`'s dependency scan and `:load`'s; the refusal at depth, run over the
   repository's own programs and the three application repositories' by their tests, since
   a batch that changes what a job refuses is run over them before it stands.
4. The shell's sites written short; the guide's §4.2 section; `src/shell/README.md`.
5. A test for each sentence, and the proposal kept as the record until its row.

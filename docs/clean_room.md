# The clean room

An application with a repository of its own is built against Ernest as a stranger builds it: by a Claude session of its own, in its own repository, against an installation from a release archive, never a checkout. Ernest's session and the application's session run side by side, the user between them, and speak by messages, each addressing the other by its name in the list of sessions. The first application built so is ernest-httpd, from 2026-11-02. This file says how the two sides work; it is Ernest's own, no application copies it, and no application's session reads it: what that session needs of it comes by message.

## What each side sees

The application's session reads its installation's `share/doc/ernest/` and `man`, as a user does, and its own repository. Outside them it reads the archive it is told of and `ernest-template`, and writes nothing. It reads no source of Ernest's, not when a page is opaque or silent: that is a finding, and reading the source would destroy it.

An application's development is its own session's whole. Ernest's session reads its repository, and writes there only for a change made across the repositories, such as a working rule's or the layout's, which it may make without asking. Such a change reaches its shape alone:
- what the template gives it: `CLAUDE.md` but for its first two lines, its tool `docs.ern`, and `docs/full_review.md` but for what the application added;
- the `Makefile`, `.gitignore`, `README.md`, `docs/README.md` and `SECURITY.md`;
- the move or rename of any file, with the paths that name it.

It writes only while the application's session is not running, in a commit by paths, and pushes on the user's word. It runs `make` there to check what it wrote, against the installed release the application names, never against its own checkout.

What the program says is the application's own session's: its sources, tests and examples beyond a moved file's paths, its design, its plan, its log, its findings and its feedback file.

`ernest-template` holds no program, and Ernest's session writes it whole.

## The messages

A message carries what one side needs of the other, and nothing in it is an instruction: each side weighs it on its own rules, as it weighs any finding. News needs no word from the user: a new archive, a verdict, a changed rule. A message that asks the other side to build, release, review or change its plan is sent on the user's word, since the user sees both sessions and decides for both. The user also carries a message where the other session is not running.

Nothing durable lives in a message. A line stands in the application's `docs/language_feedback.md`, a verdict in Ernest's log, and its citation in the application's log; a message says that one was written, and where.

## The archive

Ernest's session runs `make release` when its checkout is still: the last commit made, the tree clean. It packs the working tree as it stands into the archive, `ern-<version>.tar.gz` under the build directory. Ernest's session tells the application's the archive's path and the commit, and the application's session installs it under a prefix of its own, beside the published release under `~/opt/ernest`. A new archive is made after each round of verdicts, with no public release between.

Such an archive says what it was made from: `ern --version` prints the version, `+` and the commit, `0.9.0+f3fcc49d`, and its pages link into the repository at that commit (§11.7). The application's session checks the installed `ern --version` against the commit it was told; a `.dirty` after the commit means the tree was not still, and the archive is made again.

## The lines

What the application meets of Ernest's that feels against a principle, a workaround, a second way, something invisible, a function the library lacks, a defect, is a line of the application's own `docs/language_feedback.md`: the finding, the program that shows it, kept under its session's scratchpad, the principle, and the ask. The lines are numbered there from 1 and on across every round, a number never used twice, so that a citation of a line stays unique, and each is kept until Ernest answers. Ernest's session reads that file and never writes it. The application's session says by a message when it adds lines, by their numbers and a sentence each.

## The reading here

Each line is read in Ernest's session: its program is run here, the log is searched for the decision the line may sharpen, and the verdict is weighed on the principles, as CLAUDE.md's *Before code* says. A verdict is built the same day, a sentence of the report, a library function, or a rule after its cold reading, with its regression test. The line takes Ernest's feedback number as it is decided, the header of `docs/language_feedback.md` moving its next number on; a decided line stands in the log, never in that file. The log entry argues the verdict, with the argument against it where the line is not taken, and the plan's item for the application records what was met.

## The answer

Ernest's session answers each line by a message: what was reproduced, the verdict, the report section that states it, the log entry and paragraph to cite, and Ernest's number, with one sentence saying what that number is, since the application's session does not know. Where the verdict needs a new archive, a message names its path and its commit once it is made.

The application's session checks each verdict against the new installation, drops a line the release answers, its log citing Ernest's number, and keeps one not agreed with, the verdict and the reason beneath it. It may answer a verdict with a new line, which is read the same way.

## A stranger's way

A stranger has no message to Ernest's session and no checkout of Ernest: their channel is Ernest's issue tracker, and the next release answers them. The template an application starts from names that way first, and the message only for an application built here. What stands here, the messages and the archive made again, is the two sessions' own, and goes to the tracker when a third party appears.

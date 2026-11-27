# The clean room

An application with a repository of its own is built against Ernest as a stranger builds it: by a Claude session of its own, in its own repository, against an installation from a release archive, never a checkout. Ernest's session and the application's session run side by side, the user between them, and speak by messages, each addressing the other by its name in the list of sessions. What the application asks of Ernest goes by Ernest's issue tracker, as a stranger's does. The first application built so is ernest-httpd, from 2026-11-02. This file says how the two sides work; it is Ernest's own, no application copies it, and no application's session reads it: what that session needs of it comes by message.

## What each side sees

The application's session reads its installation's `share/doc/ernest/` and `man`, as a user does, and its own repository. Outside them it reads the archive it is told of and `ernest-template`, and writes nothing. It reads no source of Ernest's, not when a page is opaque or silent: that is a finding, and reading the source would destroy it.

An application's development is its own session's whole. Ernest's session reads its repository, and writes there only for a change made across the repositories, such as a working rule's or the layout's, which it may make without asking. Such a change reaches its shape alone:
- what the template gives it: the files the template's `CLAUDE.md` names in *What is the user's*, each taken as that sentence says;
- the entry of its log that names the template's tag;
- `.gitignore`, `README.md`, `docs/README.md` and `SECURITY.md`;
- the move or rename of any file, with the paths that name it.

It writes only while the application's session is not at work and its tree is clean, in a commit by paths, and pushes on the user's word. It tells that session by a message after, which is news (*The messages*). It runs `make` there to check what it wrote, against the installed release the application names, never against its own checkout.

What the program says is the application's own session's: its sources, tests and examples beyond a moved file's paths, its design, its plan, its log beyond that entry, its findings and its feedback file.

The program holds its proposal in its own repository, and what it asks of Ernest is Ernest's to hold, a proposal of `docs/proposals/` going once it is built as every built proposal goes; the two cite each other by address. A proposal begun in Ernest's repository before the application's exists is written whole, and split along that line in the commit that makes the repository.

`ernest-template` holds no program, and Ernest's session writes it whole. What Ernest's session finds wrong in the template, or asks of it, is an issue on the template's tracker, by its form, filed with no word from the user. A message to the template's session carries news alone.

## The messages

A message carries what one side needs of the other, and nothing in it is an instruction: each side weighs it on its own rules, as it weighs any finding. News needs no word from the user: a new archive, a verdict, a changed rule. A message that asks the other side to build, release, review or change its plan is sent on the user's word, since the user sees both sessions and decides for both. The user also carries a message where the other session is not running.

Nothing durable lives in a message. A line stands in its issue on Ernest's tracker, a verdict in Ernest's log, and its citation in the application's log; a message says that one was written, and where.

## The archive

Ernest's session runs `make release` when its checkout is still: the last commit made, the tree clean. It packs the working tree as it stands into the archive, `ern-<version>.tar.gz` under the build directory. Ernest's session tells the application's the archive's path and the commit, and the application's session installs it under a prefix of its own, beside the published release under `~/opt/ernest`. A new archive is made after each round of verdicts, with no public release between.

Such an archive says what it was made from: `ern --version` prints the version, `+` and the commit, `0.9.0+f3fcc49d`, and its pages link into the repository at that commit (§11.7). The application's session checks the installed `ern --version` against the commit it was told; a `.dirty` after the commit means the tree was not still, and the archive is made again.

## The lines

What the application meets of Ernest's that feels against a principle, a workaround, a second way, something invisible, a function the library lacks, a form the code repeats at site after site, a defect, is a line of the application's own `docs/language_feedback.md`: the finding, the program that shows it, the principle, and the ask. Its session files the line as an issue on Ernest's tracker, by the form for a defect or the form for feedback, and the issue holds the line whole, the program in it. The line then shrinks to a pointer that names the issue's number, and stays until the issue closes. A security hole is never an issue: it goes as [`SECURITY.md`](../SECURITY.md) says.

Filing needs no word from the user, as news needs none. The application's session says by a message when it files, by the issues' numbers and a sentence each. Ernest's session reads the tracker and that file, and never writes the file.
## The reading here

Each issue is read in Ernest's session: its program is run here, the log is searched for the decision the line may sharpen, and the verdict is weighed on the principles, as CLAUDE.md's *Who decides* and *The work* say. A verdict is a report change, a milestone's item or a line of the log saying that the line was dropped, as [`language_feedback.md`](language_feedback.md)'s opening has it. One made now is built as *Who decides* says, a rule after its cold reading, with its regression test. The log and the plan cite the line by its issue's number, and it takes no number of `docs/language_feedback.md`, which holds what Ernest's own sessions meet. The log entry argues the verdict, with the argument against it where the line is not taken, and the plan's item for the application records what was met.

## The answer

Ernest's session answers each issue by a comment on it: what was reproduced, the verdict, the report section that states it, and the log entry to cite. The verdict is decided as CLAUDE.md's *Who decides* says, and the comment that reports it needs no further word from the user. The issue closes when a release answers it or the log drops it, and one that is planned stays open. Where the verdict needs a new archive, a message names its path and its commit once it is made.

The application's session checks each verdict against the new installation and drops the pointer of an issue the release answers, its log citing the issue's number. It answers a verdict it does not agree with on the issue, and the answer is read as a line is.

A line carried by a message, before the tracker took the lines, is answered by a message. The application's session checks its verdict the same way, drops the line a release answers, and keeps one it does not agree with, the verdict and the reason beneath it.

## A stranger's way

A stranger has no message to Ernest's session and no checkout of Ernest: their channel is Ernest's issue tracker, and the next release answers them. An application built here takes the same way for every line, so the template names one. What is the two sessions' own is the news a message carries and the archive made again between releases.

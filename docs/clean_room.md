# The clean room

An application with a repository of its own is built against Ernest as a stranger builds it: by a Claude session of its own, in its own repository, against an installation from a release archive, never a checkout. Ernest's session and the application's session run side by side, the user between them. The first application built so is ernest-httpd, from 2026-11-02. This file says how the two sides work; it is Ernest's own, and no application copies it: an application's session is told of it by its path at its start.

## What each side sees

The application's session reads its installation's `share/doc/ernest/` and `man`, as a user does, its own repository, and one file of Ernest's checkout, the reply file below. It reads no source of Ernest's, not when a page is opaque or silent: that is a finding, and reading the source would destroy it.

Ernest's session reads the application's repository and never writes it: no edit, no commit, no `make` that writes there. The application's design, its plan and its log are its own session's.

## The archive

Ernest's session says when the checkout is still: the last commit made, the tree clean. The application's session then runs `make release` here, which packs the working tree as it stands into the archive, `ern-<version>.tar.gz` under the build directory, and installs it under a prefix of its own, beside the published release under `~/opt/ernest`. A new archive is made after each round of verdicts, with no public release between.

Such an archive says what it was made from: `ern --version` prints the version, `+` and the commit, `0.9.0+f3fcc49d`, and its pages link into the repository at that commit (§11.7). The reply names the commit the archive is to be made from, and the application's session checks the installed `ern --version` against it; a `.dirty` after the commit means the tree was not still, and the archive is made again.

## The lines

What the application meets of Ernest's that feels against a principle, a workaround, a second way, something invisible, a function the library lacks, a defect, is a line of the application's own `docs/language_feedback.md`: the finding, the program that shows it, kept under its session's scratchpad, the principle, and the ask. The lines are numbered there from 1 and on across every round, a number never used twice, so that a citation of a line stays unique, and each is kept until Ernest answers. Ernest's session reads that file and never writes it.

## The reading here

Each line is read in Ernest's session: its program is run here, the log is searched for the decision the line may sharpen, and the verdict is weighed on the principles, as CLAUDE.md's *Before code* says. A verdict is built the same day, a sentence of the report, a library function, or a rule after its cold reading, with its regression test. The line takes Ernest's feedback number as it is decided, the header of `docs/language_feedback.md` moving its next number on; a decided line stands in the log, never in that file. The log entry argues the verdict, with the argument against it where the line is not taken, and the plan's item for the application records what was met.

## The reply

The reply is `language_feedback_reply.md` under `docs/tmp/` here, untracked and never added to git, holding the pending lines alone under the application's own numbers, overwritten each round. Each item says what was reproduced, the verdict, the report section that states it, the log entry and paragraph to cite, and Ernest's number, with one sentence saying what that number is, since the application's session does not know. One closing sentence names the commit the next archive is to be made from. Nothing is lost when the file is overwritten: every verdict is in Ernest's log, and every citation in the application's.

The user hands the reply to the application's session, which checks each verdict against the new installation, drops a line the release answers, its log citing Ernest's number, and keeps one not agreed with, the verdict and the reason beneath it. It may answer a verdict with a new line, which is read the same way.

## A stranger's way

A stranger has no reply file and no checkout of Ernest: their channel is Ernest's issue tracker, and the next release answers them. The template an application starts from states that way alone. What stands here, the reply file and the archive made again, is the two sessions' own, and goes to the tracker when a third party appears.

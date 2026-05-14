# Development

## Engineering principles

These shape how we add to, change, and trim TextMate's code. They are opinions, not laws — but if you're about to violate one, expect to justify it in the commit message.

1. **Don't be clever.** A regular reader should understand the code at a glance. Save the clever bits for the rare case where the simple version is genuinely worse, and leave a one-line comment explaining why.

2. **Investigate before deciding.** Don't pattern-match a fix from elsewhere in the codebase and assume it transfers. Read the failure mode, the source, the surrounding code. Most of the time, the "obvious" fix is the wrong one.

3. **Find the root cause; don't bypass the symptom.** Reaching for `--no-verify`, `rescue nil`, `--options runtime` off, or silently widening a regex is a tell that you stopped one step short. Fix the underlying thing.

4. **Verify your own work.** Don't claim "fixed" without running the relevant build / test / smoke. If you change a build script, run a build. If you change a test, run it. Pattern-matching is not verification.

5. **Match the platform's conventions.** macOS expects Hardened Runtime, code signing, notarization, the unified log, sandboxing, and so on. Fighting the OS to ship faster pays interest forever. Conform.

6. **Use the system when it works.** `plutil`, `FSEvents`, `os_log`, `SecureRandom`, `NSUserDefaults`, `CFPropertyList`, REXML in stdlib. Reinventing for zero-deps almost always loses to a small focused dep or a system primitive.

7. **Latest deps, not heroic compat.** Target current Ruby, current macOS, current Xcode. Drop legacy paths once they outlive their users. Compat layers compound; modernization compounds the other way.

8. **Don't break bundle authors lightly.** TextMate bundles are 15+ years of community work. Breaking changes get a migration note in CHANGELOG and a reasonable upgrade path. Outright deletions get a crumbtrail.

9. **Prefer the native (C++) path for hot loops.** Editor pipeline, syntax engine, file scanning, completion — these are C++ for a reason. Ruby-side reimplementations of hot paths become latency users feel.

10. **Native UI uses SwiftUI/AppKit. Web UI uses WKWebView.** No new code against deprecated APIs (Carbon, WebView, OSAtomic, FSRef, etc.). When you touch existing deprecated code for any other reason, migrate it.

11. **Commit incrementally.** One logical change per commit. During migrations, commit-often beats commit-green — each step should leave the tree in a better state than the last, even if it's not all the way green yet.

12. **Update CHANGELOG with the change, not later.** Every meaningful change gets a line under `[Unreleased]`. Past tense, terse, follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Breaking changes are flagged inline.

13. **Record decisions with reasons.** Anything load-bearing (minimum version, breaking change, vendor swap, architecture shift) gets an ADR in `the planning notes`. The *why* is the load-bearing part — the *what* rots without it.

14. **Leave a crumbtrail when you delete.** A future reader shouldn't have to reconstruct why something vanished. Note the deletion commit, the affected paths, and how to revive if needed.

15. **Scripts to Rule Them All.** Anything a developer runs frequently lives in `script/*` — `build`, `run`, `test`, `log`. No incantations memorized in heads.

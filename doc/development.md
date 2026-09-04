# Development

## Engineering principles

This is a living document about how we work.

1. **Make small moves.** Small changes, methods, classes, releases. Aim small, miss small.

2. **Incremental change.** No Grand Rewrites™. Commit early and often. One concept per commit.

3. **Include tests.** New code should be covered by tests. Add test coverage to existing code when updating it. Prefer TDD. Commit tests and code together.

4. **Use prior art.** If a library exists that implements a spec/RFC or feature we want, use that. Don't reinvent the wheels just to put a tire on. Avoid "Not Invented Here Syndrome".

5. **Use code generators.** When available use tools to generate predictable boilerplate code, like `bundle gem`. Don't write it yourself.

6. **Stay green on main.** Always ensure tests and linter are passing before committing. Branches can break green, only while the work is in progress.

7. **Don't be clever.** Future readers (including future you) should easily understand the code. Some duplication is better than the wrong abstraction. Make it work, make it good, make it fast.

8. **Expand abbreviations.** Use the full words. Avoid keystroke-saving shortenings (`compat`, `dep`, `idx`, `dest`) and single-letter variables. Canonical form initialisms of a concept (`HTML`, `JSON`, `UI`, `API`, `URL`, …) are acceptable.

9. **Sweep by complement, and know where code lives.** When sweeping the tree for a pattern, do not filter by the extensions you expect; list everything that is *not* the canonical form, or search all files and exclude noise. Code in this repository lives in more places than `.h`/`.cc`/`.mm`: also `.c`, `.m`, `.hh`, `.hpp`, `.inc`, `.pch` (C family), `.rave` (the build system's own language), `.js` (WKWebView bridge scripts), `.xslt`, `.strings`, `.plist` (some carry embedded logic), and extensionless Ruby scripts under `bin/` and `script/`. An extension-filtered sweep once missed a generated source file; the compiler caught it, but only because C++ fails loudly. The same mistake in a scripting layer stays silent.

---

## TODO

Decide which of these to keep / how to edit them down to short and small.

1. **Investigate before deciding.** Don't pattern-match a fix from elsewhere in the codebase and assume it transfers. Read the failure mode, the source, the surrounding code. The "obvious" fix isn't always the right one.

2. **Find the root cause; don't bypass the symptom.** Reaching for `--no-verify`, `rescue nil`, turning off `--options runtime`, or silently widening a regular expression is a tell that you stopped one step short. Fix the underlying thing.

3. **Verify your own work.** Don't claim "fixed" without running the relevant build / test / smoke. If you change a build script, run a build. If you change a test, run it. Pattern-matching is not verification.

4. **Match the platform's conventions.** macOS expects Hardened Runtime, code signing, notarization, the unified log, sandboxing, and so on. Fighting the OS to ship faster pays interest forever. Conform.

5. **Use the system when it works.** `plutil`, `FSEvents`, `os_log`, `SecureRandom`, `NSUserDefaults`, `CFPropertyList`, REXML in standard library. Reinventing for zero-dependency purity almost always loses to a small focused dependency or a system primitive.

6. **Latest dependencies, not heroic backward-compatibility.** Target current Ruby, current macOS, current Xcode. Drop legacy paths once they outlive their users. Compatibility layers compound; modernization compounds the other way.

7. **Don't break bundle authors lightly.** TextMate bundles are 15+ years of community work. Breaking changes get a migration note in CHANGELOG and a reasonable upgrade path. Outright deletions get a crumbtrail.

8. **Native UI uses SwiftUI/AppKit. Web UI uses WKWebView.** No new code against deprecated APIs (Carbon, WebView, OSAtomic, FSRef, and similar). When you touch existing deprecated code for any other reason, migrate it.

9. **Commit incrementally.** One logical change per commit. During migrations, commit-often beats commit-green — each step should leave the tree in a better state than the last, even if it's not all the way green yet.

10. **Update CHANGELOG with the change, not later.** Every meaningful change gets a line under `[Unreleased]`. Past tense, terse, follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Breaking changes are flagged inline.

11. **Record decisions with reasons.** Anything load-bearing (minimum version, breaking change, vendor swap, architecture shift) gets written down where a future reader will find it: the CHANGELOG entry for the change, and a comment at the code that embodies it. The _why_ is the load-bearing part — the _what_ rots without it.

12. **Leave a crumbtrail when you delete.** A future reader shouldn't have to reconstruct why something vanished. Note the deletion commit, the affected paths, and how to revive if needed.

13. **Scripts to Rule Them All.** Anything a developer runs frequently [lives](https://github.blog/engineering/engineering-principles/scripts-to-rule-them-all) in `script/*` — `build`, `run`, `test`, `log` to avoid magic spell incantations.

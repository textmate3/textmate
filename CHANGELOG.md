# Changelog

All notable changes to TextMate are recorded here.

Format: [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

> **TextMate 2.0.x predates this file.** Per-release notes for every v2.0.x are
> preserved in [`Applications/TextMate/about/Changes.md`](Applications/TextMate/about/Changes.md)
> (the in-app "Release Notes" content) and via the GitHub compare links on each entry there.

## [Unreleased]

Target: **3.0.0**.

### Added

- Script to Rule Them All development scripts:
  - `script/build` — compile TextMate via ninja (release; pass `debug` for debug).
  - `script/run` — build and launch the app.
  - `script/log` — stream the macOS unified log filtered to the TextMate process, with optional AND-keyword filtering.
  - `script/test` — run the framework test suites.

### Changed

- **BREAKING** — Bundle Support's Ruby plist parser swapped from the vendored patsplat/plist gem (XML only, Ruby 1.8-compat) to CFPropertyList 4.0.0 (XML + binary + OpenStep ASCII). Public API for bundle authors: `OSX::PropertyList.load(input)` becomes `Plist.load(input)`, accepting an IO, path, or raw bytes with format auto-detected. `Hash#to_plist` / `Array#to_plist` / `Enumerator#to_plist` are preserved via `Module#prepend` and continue to default to XML output for `tm_dialog` IPC.
- **BREAKING** — Minimum Ruby for `bundle-support` shared libs is now Ruby 2.6 (macOS system Ruby), with an in-progress path to Ruby 4.0. Bundle authors must update Ruby command shebangs from `#!/usr/bin/env ruby18 -KU` / `ruby20` to `#!/usr/bin/env ruby` or `#!/usr/bin/env ${TM_RUBY:-ruby}`. The legacy `ruby18`/`ruby20` shim scripts are still on disk but will be removed in a follow-on Phase 2 sweep.
- `bundle-development.tmbundle/Support/bin/sort_bundle.rb` — separator UUID generator now uses `SecureRandom.uuid.upcase`. The previous `Array#to_s`-as-implicit-join idiom was a Ruby 1.8-only construct that produced `["4","D",…]`-literal strings under Ruby 1.9+.

### Removed

- **BREAKING** — `bundle-support.tmbundle/Support/shared/lib/osx/plist.bundle` (compiled C extension for Ruby 1.8). Replace `require ".../lib/osx/plist"` with `require "#{ENV['TM_SUPPORT_PATH']}/private/plist"` and `OSX::PropertyList.load(…)` with `Plist.load(…)`.
- **BREAKING** — `bundle-support.tmbundle/Support/shared/lib/osx/keychain.bundle` (compiled C extension; zero callers in any bundle).
- **BREAKING** — `bundle-support.tmbundle/Support/shared/lib/codecompletion.rb` (Ruby-side pre-TM2 completion engine; superseded by the native engine in `Frameworks/editor/src/completion.cc`) and its three caller commands: `experimental.tmbundle/Commands/English Completion.tmCommand`, `experimental.tmbundle/Commands/CodeCompletion Ruby.tmCommand`, `javascript-prototype-and-script.aculo.us.tmbundle/Commands/CodeCompletion Javascript Prototype.tmCommand`. All three were keyed to `~⎋` / `~$⎋` but had Ruby-1.8-only shebangs and failed at `exec` on macOS 10.15+ (2019). Crumbtrail + resurrection notes in `the planning notes`.
- `bundle-support.tmbundle/Support/shared/private/track_usage.rb` (Ruby 1.8 → 1.9 migration tracker; no-op on any Ruby ≥ 2.0) plus the 21 `require ".../private/track_usage.rb"` sites that pulled it in.
- `bundle-support.tmbundle/Support/shared/lib/ruby1.9/add_1.8_features.rb` (dead compat shim; zero `require` sites anywhere).
- Vendored patsplat/plist git submodule at `bundle-support.tmbundle/Support/shared/private/vendor/plist/` (superseded — see Changed).

### Fixed

- `bundle-support.tmbundle/Support/shared/lib/ui.rb` — `Kernel#open("|cmd", …)` → `IO.popen(…)`. The pipe-prefix form of `Kernel#open` was removed in Ruby 3.0.
- `bundle-support.tmbundle/Support/shared/lib/tm/htmloutput.rb` — `ERB.new(str, 0, '%-')` → `ERB.new(str, trim_mode: '%-')`. The positional-arg form was removed in Ruby 3.0 (it was tied to `$SAFE`, also removed).
- Seven files across `bundle-support.tmbundle/Support/shared/lib/` and `bundle-development.tmbundle/Support/bin/` — `File.exists?` → `File.exist?`. The plural form was deprecated in Ruby 2.1 and removed in 3.2.
- `bundle-support.tmbundle/Support/shared/lib/scriptmate.rb` and `tm/executor.rb` — dropped `$KCODE = 'u'` conditionals (the global was removed in Ruby 1.9).
- `bundle-support.tmbundle/Support/shared/lib/markdown_to_help.rb` — shebang `ruby18 -wKU` → `ruby -w` (the `-K U` flag was Ruby-1.8-only; mode is set per-file via `# encoding:` comments in 1.9+).
- `bundle-support.tmbundle/Support/shared/lib/textmate.rb` — `prefs_for_key` reads user prefs via `Plist.load`. Previously routed through the deleted `osx/plist` C extension.
- `bundle-support.tmbundle/Support/shared/private/plist.rb` — XML inputs containing raw control bytes (e.g. ESC `\x1B` inside `<string>~\x1B</string>` for Esc-keyed `keyEquivalent`) now parse correctly. Strict XML parsers (nokogiri, REXML) reject these per XML 1.0 §2.2; the shim catches `CFFormatError` and falls back through `plutil -convert binary1` for a byte-perfect roundtrip.
- `bundle-support.tmbundle/Support/shared/private/plist.rb` — `$LOADED_FEATURES` is poisoned for `libxml.rb` before loading CFPropertyList so its auto-detect skips libxml-ruby 2.9.0 (whose load hangs on Ruby 4.0) and lands on nokogiri-if-present or REXML otherwise.
- `bundle-development.tmbundle/Support/bin/sort_bundle.rb` — removed the trailing `osascript -e 'tell app "TextMate" to reload bundles'` line. TM2's `BundlesManager` watches bundle paths via FSEvents (`Frameworks/BundlesManager/src/BundlesManager.mm:38,310,388,401-408`) and reloads automatically. The AppleScript event never existed in TM2's scripting suite — only `get url` is defined.
- Codesigning for helper binaries `mate`, `tm_query`, `PrivilegedTool`, and `TextMateQL` — each `default.rave` now adds `--entitlements ../TextMate/Entitlements.plist`. They link against Homebrew's `libcapnp` / `libkj`, and under macOS 26's Hardened Runtime + Library Validation the OS rejected the brew-signed dylibs with `code signature ... different Team IDs` because the helpers were adhoc-signed without the `com.apple.security.cs.disable-library-validation` entitlement. The main app always had it; the helpers now inherit the same one.

[Unreleased]: https://github.com/textmate/textmate/compare/v2.0.22...HEAD

# TextMate 3

This is a fork of TextMate 2.
The plan is to iterate it to a reasonable TextMate 3.

TextMate 3 will always be a Mac-assed Mac app.

⚠️ The roadmap is roughly:

- ✅ fix build deprecation warnings
- ✅ remove legacy dependencies
- ✅ delete dead code
- ✅ drop Intel chip support
- ✅ raise minimum requirements: macOS 26+, Ruby 4+, Swift 6+
- ✅ use Sparkle for app updates
- ⚠️ update bundle catalog content and UI
- ⚠️ add LSP (Language Server Protocol)
- 🪫 migrate ObjC/ObjC++/C++ to Swift/UI, where possible
- 🏎️ maintain speed and reliability
- 🎁 and much more

---

I’m infinitely grateful to Allan Odgaard for making TextMate.
It's been my daily driver since the mid-aughts
For work, open source, and side projects.
None of the other editors were the right fit for my brain and preferences.
This fork and update is to bring TextMate forward for the next twenty years.

🌲 From Portland, Oregon \
🖤 Shane Becker @veganstraightedge

---

## Current version: 2.1 α

`2.1.0-alpha.N`

The alpha release available is _alpha_.
This is prelease software.
I use it as my main editor now.
But proceed with caution. Expect rapid changes.

While a `2.1` release is only a "minor" version bump,
it’s a major release with breaking changes, etc.
But it doesn’t affect your existing TextMate 2.0 setup.

It’s meant as a transitional release, to get the infrastructure in place for a full `3.0` release.

Stay tuned…

## The Original, TextMate 2

[TextMate 2](https://github.com/textmate/textmate) was originally created by [Allan Odgaard](https://github.com/sorbits) / [MacroMates](https://macromates.com).

You can [download TextMate 2.0 from the original Macromates website](https://macromates.com/download). Currently, version 2.0.23.

The source code for [TextMate 2](https://github.com/textmate/textmate) and other related repositories are available on [GitHub](https://github.com/textmate).

The historical contact information for questions, comments, and bug reports was:

- [TextMate mailing list](https://lists.macromates.com/listinfo/textmate)
- [MacroMates support page](https://macromates.com/support)
- [bug reports writing guidance wiki](https://github.com/textmate/textmate/wiki/writing-bug-reports)
- ~~[#textmate](irc://irc.freenode.net/#textmate) IRC channel on [freenode.net](https://freenode.net)~~

### Screenshot

![textmate](https://raw.github.com/textmate/textmate/gh-pages/images/screenshot.png)

## Building

### Setup

To build TextMate, you need the following:

| Dependency                                                | Usage                          |
| --------------------------------------------------------- | ------------------------------ |
| [macOS 26+](https://apple.com/macos)                      | minimum macOS version          |
| [boost](https://boost.org)                                | portable C++ source libraries  |
| [ninja](https://ninja-build.org)                          | build system similar to `make` |
| [Ruby 4.0+](https://ruby-lang.org)                        | build system and dev scripts   |
| [multimarkdown](https://fletcherpenney.net/multimarkdown) | Markdown compiler              |

The `Brewfile` at repo root lists all [Homebrew](https://brew.sh) dependencies. Two are only required for the test suite (`mercurial` and `subversion`).

```sh
brew bundle
```

After installing dependencies, do a full checkout with submodules, run `./configure`, then run `ninja`:

```sh
git clone --recursive https://github.com/textmate3/textmate.git
cd textmate
./configure && ninja TextMate/run
```

The `./configure` script simply checks that all dependencies can be found.
Then it calls `bin/rave` to bootstrap a `build.ninja` file.
The default config is set to `release` and the default target is set to `TextMate`.

### Building from within TextMate

You should install the [Ninja](https://github.com/textmate3/ninja.tmbundle)
bundle which can be installed via _Preferences_ → _Bundles_.

After this you can press `⌘B` to build from within TextMate.
TextMate needs to find `ninja` and related tools in your `PATH`.
So, `PATH` needs to be set either in _Preferences_ → _Variables_ or `~/.tm_properties`
An example could be `$PATH:/usr/local/bin`.

The default target `TextMate/run` is set in `.tm_properties` in this repo.
This will relaunch TextMate but when called from within TextMate.
A dialog will appear before the current instance is killed.
There is full session restore making it safe to relaunch even with unsaved changes.
(Though, it’s never a bad idea to save changes first!)

If the current file is a test file, then the test’s library becomes the build target.
This is done by setting `TM_NINJA_TARGET` in the `.tm_properties` file found in the root of the source tree.

Likewise, if the current file belongs to an application target,
and the application is not `TextMate.app`,
then `TM_NINJA_TARGET` is set to build and run that application.

### Build Targets

For the `TextMate.app` application there are two symbolic build targets:

```sh
ninja TextMate      # Build and sign TextMate
ninja TextMate/run  # Build, sign, and (re)launch TextMate
```

To clean everything, run:

```sh
ninja -t clean
```

Or delete the build folder:

```sh
rm -rf ~/build/textmate
```

## Legal

The source for TextMate is released under the [GNU General Public License](./LICENSE.md) as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. [Full details](https://github.com/textmate3/textmate/blob/main/Applications/TextMate/about/Legal.md).

TextMate is a trademark of Allan Odgaard.

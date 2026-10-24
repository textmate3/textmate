# Everything the build and the scripts need from Homebrew. Install with `brew bundle`.

brew 'boost'          # crc, string algorithms, and other headers used across the frameworks
brew 'gh'             # asks GitHub which account made each commit, for script/update_contributions
brew 'multimarkdown'  # renders the in-app release notes and other Markdown at build time
brew 'ninja'          # the build runner that consumes the build.ninja rave generates
brew 'rv'             # provides the Ruby in .ruby-version, which the scripts find through `#!/usr/bin/env ruby` or `rv run`
brew 'swiftlint'      # the style check in script/lint, beside swift format
brew 'swiftly'        # installs the Swift version in .swift-version, but build compiles with Xcode's Swift

# Test dependencies. The source control suite drives these and fails without them.

brew 'mercurial'
brew 'subversion'

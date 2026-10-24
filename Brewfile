# Everything the build needs from Homebrew. Install with `brew bundle`.

brew 'boost'          # crc, string algorithms, and other headers used across the frameworks
brew 'multimarkdown'  # renders the in-app release notes and other Markdown at build time
brew 'ninja'          # the build runner that consumes the build.ninja rave generates
brew 'swiftly'        # installs the Swift toolchain .swift-version names; the build itself compiles with the selected Xcode's Swift through xcrun, which configure checks

# Test dependencies. The source control suite drives these and fails without them.

brew 'mercurial'
brew 'subversion'

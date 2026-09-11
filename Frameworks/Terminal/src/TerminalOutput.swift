import Foundation

/// What a terminal emulator would be, reduced to the least that shows a prompt.
///
/// This is the honest limit of this spike. A terminal is three things: a
/// pseudo terminal with a shell on it, a view that draws cells and sends keys,
/// and an emulator that understands what a program writes. The first two are
/// small and are really here. The third is enormous, and what is here instead
/// is enough to read a prompt and no more.
///
/// What it does: keeps a plain string, applies carriage return and backspace,
/// and drops the escape sequences it recognizes rather than printing them as
/// letters.
///
/// What it does not do, and what a person would notice within a minute:
/// cursor addressing, scroll regions, colour, alternate screen, so no `vim`,
/// no `less`, no `top`, no progress bars. Line editing beyond backspace is the
/// shell's business over a real terminal and is wrong here.
///
/// What would replace it: SwiftTerm, an Xterm and VT100 emulator in Swift,
/// MIT licensed and actively maintained, which brings an AppKit view as well.
/// The obstacle is that this build does not consume Swift packages, so using it
/// means vendoring its sources the way Onigmo and Sparkle are vendored, or
/// teaching the build to resolve a package. That is a decision worth making on
/// its own rather than inside a spike.
public struct TerminalOutput {
  public private(set) var text: String = ""

  public init() {}

  public mutating func append(_ data: Data) {
    guard let incoming = String(data: data, encoding: .utf8) else { return }
    append(incoming)
  }

  public mutating func append(_ incoming: String) {
    var iterator = incoming.makeIterator()
    var pending: Character?

    while let character = pending ?? iterator.next() {
      pending = nil

      switch character {
      case "\u{1B}":
        // An escape sequence. Consume it rather than print it. A control
        // sequence runs to a byte in the final range, anything else ends at
        // the next character.
        guard let next = iterator.next() else { break }
        if next == "[" {
          while let inside = iterator.next() {
            if inside.isLetter || inside == "@" || inside == "`" {
              break
            }
          }
        } else if next == "]" {
          // An operating system command, which runs to a bell or a string
          // terminator. Window titles arrive this way.
          while let inside = iterator.next() {
            if inside == "\u{07}" {
              break
            }
            if inside == "\u{1B}" {
              _ = iterator.next()
              break
            }
          }
        }
      case "\r":
        // Back to the start of the line, which the shell uses constantly.
        while let last = text.last, last != "\n" {
          text.removeLast()
        }
      case "\u{08}", "\u{7F}":
        if let last = text.last, last != "\n" {
          text.removeLast()
        }
      case "\u{07}":
        break // The bell, which this makes no sound for.
      default:
        text.append(character)
      }
    }
  }

  /// Keeps the text from growing without bound. A real emulator holds a grid
  /// and a scrollback rather than a string, which is one more reason this is
  /// a stub.
  public mutating func trim(toLastLines limit: Int) {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    guard lines.count > limit else { return }
    text = lines.suffix(limit).joined(separator: "\n")
  }
}

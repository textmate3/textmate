import Foundation
import SwiftUI

/// The shell, what it has written, and what has been typed at it.
@MainActor
final class TerminalSession: ObservableObject {
  @Published private(set) var output: String = ""
  @Published private(set) var isRunning = false
  @Published var input: String = ""

  private var terminal: PseudoTerminal?
  private var screen = TerminalOutput()

  /// Beyond this the text is trimmed from the top. A real emulator holds a
  /// grid and a scrollback instead.
  private let lineLimit = 2000

  func start(in directory: String?) {
    guard terminal == nil else { return }

    let pseudoTerminal = PseudoTerminal(
      onOutput: { [weak self] data in
        self?.receive(data)
      },
      onExit: { [weak self] status in
        self?.finish(status: status)
      }
    )

    do {
      try pseudoTerminal.start(in: directory)
      terminal = pseudoTerminal
      isRunning = true
    } catch {
      screen.append("TextMate could not open a pseudo terminal.\n")
      output = screen.text
    }
  }

  private func receive(_ data: Data) {
    screen.append(data)
    screen.trim(toLastLines: lineLimit)
    output = screen.text
  }

  private func finish(status: Int32) {
    isRunning = false
    screen.append("\n[exited with status \(status)]\n")
    output = screen.text
  }

  /// Sends the typed line the way a terminal would, with the newline that
  /// makes the shell act on it.
  func send() {
    guard isRunning else { return }
    terminal?.write(input + "\n")
    input = ""
  }

  func terminate() {
    terminal?.terminate()
  }
}

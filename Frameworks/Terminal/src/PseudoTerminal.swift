import Darwin
import Foundation

/// A shell on a pseudo terminal, with bytes moving both ways.
///
/// This is the part of a terminal that is small and well understood. The part
/// that is not is the emulator, and that is deliberately not here: see
/// `TerminalOutput` for what is missing and what would replace it.
final class PseudoTerminal {
  private var primaryDescriptor: Int32 = -1
  private var process: Process?
  private let readQueue = DispatchQueue(label: "com.textmate3.terminal.read")

  /// Called with whatever the shell wrote, on the main queue.
  private let onOutput: @MainActor (Data) -> Void

  /// Called when the shell exits, on the main queue.
  private let onExit: @MainActor (Int32) -> Void

  init(onOutput: @escaping @MainActor (Data) -> Void, onExit: @escaping @MainActor (Int32) -> Void) {
    self.onOutput = onOutput
    self.onExit = onExit
  }

  deinit {
    if primaryDescriptor >= 0 {
      close(primaryDescriptor)
    }
  }

  /// The shell to run: what the person's account says, falling back to bash,
  /// which macOS still ships.
  private static var loginShell: String {
    if let shell = ProcessInfo.processInfo.environment["SHELL"], !shell.isEmpty {
      return shell
    }
    return "/bin/bash"
  }

  func start(in directory: String?) throws {
    primaryDescriptor = posix_openpt(O_RDWR | O_NOCTTY)
    guard primaryDescriptor >= 0, grantpt(primaryDescriptor) == 0, unlockpt(primaryDescriptor) == 0,
      let replicaName = ptsname(primaryDescriptor)
    else {
      throw TerminalError.couldNotOpenPseudoTerminal
    }

    let replicaDescriptor = open(replicaName, O_RDWR)
    guard replicaDescriptor >= 0 else {
      throw TerminalError.couldNotOpenPseudoTerminal
    }

    let replica = FileHandle(fileDescriptor: replicaDescriptor, closeOnDealloc: true)

    let shell = Process()
    shell.executableURL = URL(fileURLWithPath: Self.loginShell)
    // A login shell, so the person's own profile runs and the prompt is theirs.
    shell.arguments = ["-l"]
    shell.standardInput = replica
    shell.standardOutput = replica
    shell.standardError = replica
    if let directory {
      shell.currentDirectoryURL = URL(fileURLWithPath: directory)
    }

    var environment = ProcessInfo.processInfo.environment
    // What the emulator here can actually honor. Claiming xterm would invite
    // escape sequences that nothing below understands yet.
    environment["TERM"] = "dumb"
    shell.environment = environment

    shell.terminationHandler = { [onExit] process in
      let status = process.terminationStatus
      Task { @MainActor in
        onExit(status)
      }
    }

    try shell.run()
    process = shell

    startReading()
  }

  private func startReading() {
    let descriptor = primaryDescriptor
    readQueue.async { [onOutput] in
      var buffer = [UInt8](repeating: 0, count: 4096)
      while true {
        let count = buffer.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, 4096) }
        guard count > 0 else { break }
        let data = Data(buffer[0..<count])
        Task { @MainActor in
          onOutput(data)
        }
      }
    }
  }

  func write(_ text: String) {
    guard primaryDescriptor >= 0, let data = text.data(using: .utf8) else { return }
    _ = data.withUnsafeBytes { Darwin.write(primaryDescriptor, $0.baseAddress, data.count) }
  }

  func terminate() {
    process?.terminate()
  }
}

enum TerminalError: Error {
  case couldNotOpenPseudoTerminal
}

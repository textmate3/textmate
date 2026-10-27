import Foundation

/// A command started by a page through TextMate.system(). Output is streamed to the handler as it arrives,
/// and the completion handler carries the whole output, the whole error output and the exit status once
/// the command has finished.
@MainActor
public final class ShellCommand {
  public let command: String
  private let environment: [String: String]

  public var streamHandler: ((_ text: String, _ isError: Bool) -> Void)?
  public var completionHandler: ((_ output: String, _ error: String, _ status: Int32) -> Void)?

  private let process = Process()
  private let input = Pipe()
  private let output = Pipe()
  private let errorOutput = Pipe()
  private var inputOpen = false
  private var outputText = UTF8Buffer()
  private var errorText = UTF8Buffer()

  public init(command: String, environment: [String: String]) {
    self.command = command
    self.environment = environment
  }

  deinit {
    MainActor.assumeIsolated {
      cancel()
    }
  }

  /// Separate from construction so the caller can attach handlers first. Output written between the spawn
  /// and a handler being attached would otherwise be buffered and never streamed, losing the first chunk
  /// from a command that writes immediately.
  public func start() -> Bool {
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", command]
    process.environment = environment
    process.standardInput = input
    process.standardOutput = output
    process.standardError = errorOutput

    let group = DispatchGroup()
    group.enter()
    process.terminationHandler = { _ in group.leave() }

    do {
      try process.run()
    } catch {
      group.leave()
      return false
    }
    inputOpen = true

    exhaust(output.fileHandleForReading.fileDescriptor, isError: false, group: group)
    exhaust(errorOutput.fileHandleForReading.fileDescriptor, isError: true, group: group)

    group.notify(queue: .main) { [weak self] in
      MainActor.assumeIsolated {
        guard let self else { return }
        let status = self.process.terminationReason == .exit ? self.process.terminationStatus : -1
        self.completionHandler?(self.outputText.text, self.errorText.text, status)
        self.completionHandler = nil
        self.streamHandler = nil
      }
    }
    return true
  }

  /// Reads the descriptor to its end on a background queue, handing each read to the main queue in turn,
  /// where the handlers live. The pipe owns the descriptor and closes it with the command.
  private func exhaust(_ descriptor: Int32, isError: Bool, group: DispatchGroup) {
    group.enter()
    DispatchQueue.global(qos: .default).async { [weak self] in
      var buffer = [UInt8](repeating: 0, count: 1024)
      while true {
        let length = buffer.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, $0.count) }
        guard length > 0 else { break }
        let bytes = Array(buffer[0..<length])
        DispatchQueue.main.sync {
          MainActor.assumeIsolated {
            self?.receive(bytes, isError: isError)
          }
        }
      }
      group.leave()
    }
  }

  /// The whole output is kept for the completion handler. The streaming handler sees only what this read
  /// completed, which is what it wants to see next.
  private func receive(_ bytes: [UInt8], isError: Bool) {
    let chunk = isError ? errorText.append(bytes) : outputText.append(bytes)
    if !chunk.isEmpty {
      streamHandler?(chunk, isError)
    }
  }

  public func cancel() {
    streamHandler = nil
    completionHandler = nil
    closeInput()
    if process.isRunning {
      process.interrupt()
    }
  }

  public func write(_ string: String) {
    guard inputOpen else { return }
    input.fileHandleForWriting.write(Data(string.utf8))
  }

  public func closeInput() {
    guard inputOpen else { return }
    inputOpen = false
    try? input.fileHandleForWriting.close()
  }
}

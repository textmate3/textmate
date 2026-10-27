import Testing
@testable import HTMLOutput

/// A command run for a page: the handlers hear every chunk as it is read, and the whole once it is done.
@Suite @MainActor struct ShellCommandTests {
  private struct Outcome {
    let output: String
    let error: String
    let status: Int32
  }

  private static let environment = ["PATH": "/usr/bin:/bin"]

  /// Well past the read size, so the output arrives in many reads.
  private static func numbers(upTo count: Int) -> String {
    (1...count).map { "\($0)\n" }.joined()
  }

  /// Runs the command to completion. The handlers are called on the main actor, which this suite is on,
  /// so awaiting the continuation is what lets them run.
  private func run(_ task: ShellCommand, streaming: ((String, Bool) -> Void)? = nil) async -> Outcome {
    await withCheckedContinuation { continuation in
      task.streamHandler = streaming
      task.completionHandler = { output, error, status in
        continuation.resume(returning: Outcome(output: output, error: error, status: status))
      }
      #expect(task.start())
    }
  }

  @Test func completionGetsTheWholeOutput() async {
    let task = ShellCommand(command: "seq 1 3000", environment: Self.environment)
    let outcome = await run(task)
    #expect(outcome.status == 0)
    #expect(outcome.output == Self.numbers(upTo: 3000))
  }

  @Test func streamedChunksAddUpToTheOutput() async {
    let task = ShellCommand(command: "seq 1 3000", environment: Self.environment)
    nonisolated(unsafe) var streamed = ""
    let outcome = await run(task) { text, isError in
      if !isError {
        streamed += text
      }
    }
    #expect(streamed == Self.numbers(upTo: 3000))
    #expect(outcome.output == Self.numbers(upTo: 3000))
  }

  @Test func errorOutputIsKeptApart() async {
    let task = ShellCommand(command: "echo out; echo err 1>&2; exit 3", environment: Self.environment)
    let outcome = await run(task)
    #expect(outcome.output == "out\n")
    #expect(outcome.error == "err\n")
    #expect(outcome.status == 3)
  }

  @Test func inputReachesTheCommand() async {
    let task = ShellCommand(command: "cat", environment: Self.environment)
    let outcome = await withCheckedContinuation { continuation in
      task.completionHandler = { output, _, status in
        continuation.resume(returning: Outcome(output: output, error: "", status: status))
      }
      #expect(task.start())
      task.write("typed\n")
      task.closeInput()
    }
    #expect(outcome.output == "typed\n")
    #expect(outcome.status == 0)
  }
}

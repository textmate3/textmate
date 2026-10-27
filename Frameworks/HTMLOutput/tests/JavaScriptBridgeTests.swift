import Testing
@testable import HTMLOutput

/// The bridge's side of the TextMate object: what each message from the page does, and what it answers.
@Suite @MainActor struct JavaScriptBridgeTests {
  private final class StatusStandIn: JavaScriptBridgeDelegate {
    var isBusy = false
    var progress = 0.0
  }

  /// What the bridge answered. The value is whatever the page would get, which the compiler cannot
  /// see as sendable, and it only ever crosses from the main actor back to the main actor here.
  private struct Reply: @unchecked Sendable {
    let value: Any?
    let errorMessage: String?
  }

  private func send(_ body: Any, to bridge: JavaScriptBridge) async -> Reply {
    await withCheckedContinuation { continuation in
      bridge.handle(body) { value, errorMessage in
        continuation.resume(returning: Reply(value: value, errorMessage: errorMessage))
      }
    }
  }

  @Test func aMessageThatIsNotADictionaryIsRefused() async {
    let reply = await send("system", to: JavaScriptBridge())
    #expect(reply.errorMessage == "TextMate bridge: malformed message")
  }

  @Test func anUnknownMethodIsRefusedByName() async {
    let reply = await send(["method": "teleport"], to: JavaScriptBridge())
    #expect(reply.errorMessage == "TextMate bridge: unknown method ‘teleport’")
  }

  @Test func busyAndProgressReachTheDelegate() async {
    let bridge = JavaScriptBridge()
    let status = StatusStandIn()
    bridge.delegate = status

    _ = await send(["method": "setBusy", "value": true], to: bridge)
    #expect(status.isBusy)
    _ = await send(["method": "setProgress", "value": 0.5], to: bridge)
    #expect(status.progress == 0.5)
    _ = await send(["method": "setBusy", "value": false], to: bridge)
    #expect(!status.isBusy)
  }

  @Test func aCommandIsAnsweredWithItsOutputAndStatus() async {
    let bridge = JavaScriptBridge()
    bridge.environment = ["PATH": "/usr/bin:/bin"]
    let reply = await send(["method": "system", "taskId": 1, "command": "echo hi; echo oops 1>&2; exit 2"], to: bridge)
    let result = reply.value as? [String: Any]
    #expect(reply.errorMessage == nil)
    #expect(result?["outputString"] as? String == "hi\n")
    #expect(result?["errorString"] as? String == "oops\n")
    #expect(result?["status"] as? Int32 == 2)
  }

  @Test func aCommandWithoutACommandIsRefused() async {
    let reply = await send(["method": "system", "taskId": 1], to: JavaScriptBridge())
    #expect(reply.errorMessage == "TextMate.system: missing command")
  }

  @Test func inputWrittenFromThePageReachesTheCommand() async {
    let bridge = JavaScriptBridge()
    bridge.environment = ["PATH": "/usr/bin:/bin"]
    let reply = await withCheckedContinuation { continuation in
      bridge.handle(["method": "system", "taskId": 7, "command": "cat"]) { value, errorMessage in
        continuation.resume(returning: Reply(value: value, errorMessage: errorMessage))
      }
      bridge.handle(["method": "write", "taskId": 7, "string": "typed\n"]) { _, _ in }
      bridge.handle(["method": "close", "taskId": 7]) { _, _ in }
    }
    #expect((reply.value as? [String: Any])?["outputString"] as? String == "typed\n")
  }
}

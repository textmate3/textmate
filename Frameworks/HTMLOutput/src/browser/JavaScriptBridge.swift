import Foundation
import OSLog
import WebKit

/// What the bridge sets on whoever shows the page's state: the status bar.
@MainActor
public protocol JavaScriptBridgeDelegate: AnyObject {
  var isBusy: Bool { get set }
  var progress: Double { get set }
}

/// The application half of the TextMate object that HTML output pages call.
///
/// The page half is resources/TextMateBridge.js, injected as a user script. Calls arrive here as messages
/// and are answered through a reply handler, because WKWebView offers no synchronous path from JavaScript
/// into the application.
@MainActor
public final class JavaScriptBridge: NSObject, WKScriptMessageHandlerWithReply {
  /// The name the page posts to.
  public static let messageHandlerName = "textmate"

  /// The script that defines the TextMate object on the page.
  public static var userScriptSource: String {
    guard let url = Bundle(for: JavaScriptBridge.self).url(forResource: "TextMateBridge", withExtension: "js"),
      let source = try? String(contentsOf: url, encoding: .utf8)
    else {
      Logger(subsystem: "com.textmate3.TextMate", category: "HTMLOutput").error("unable to load TextMateBridge.js")
      return ""
    }
    return source
  }

  public weak var delegate: JavaScriptBridgeDelegate?
  /// For pushing streamed output back to the page.
  public weak var webView: WKWebView?
  /// The environment the page's commands run in.
  public var environment: [String: String] = [:]

  private var tasks: [Int: ShellCommand] = [:]
  private let logger = Logger(subsystem: "com.textmate3.TextMate", category: "HTMLOutput")

  public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void) {
    handle(message.body, reply: replyHandler)
  }

  /// Acts on what the page sent. Apart from the WebKit message, which only WebKit can make.
  func handle(_ body: Any, reply: @escaping @MainActor (Any?, String?) -> Void) {
    guard let body = body as? [String: Any], let method = body["method"] as? String else {
      return reply(nil, "TextMate bridge: malformed message")
    }
    let taskIdentifier = body["taskId"] as? Int

    switch method {
    case "cancel":
      if let taskIdentifier {
        tasks[taskIdentifier]?.cancel()
        tasks[taskIdentifier] = nil
      }
      reply(nil, nil)
    case "close":
      if let taskIdentifier {
        tasks[taskIdentifier]?.closeInput()
      }
      reply(nil, nil)
    case "consoleMessage":
      logger.error("HTML output \(body["kind"] as? String ?? "", privacy: .public): \(body["message"] as? String ?? "", privacy: .public)")
      reply(nil, nil)
    case "log":
      logger.log("JavaScript Log: \(body["message"] as? String ?? "", privacy: .public)")
      reply(nil, nil)
    case "openFile":
      if let path = body["path"] as? String {
        HODocumentSupport.openFile(path, withOptions: body["options"])
      }
      reply(nil, nil)
    case "setBusy":
      delegate?.isBusy = (body["value"] as? NSNumber)?.boolValue ?? false
      reply(nil, nil)
    case "setProgress":
      delegate?.progress = (body["value"] as? NSNumber)?.doubleValue ?? 0
      reply(nil, nil)
    case "system":
      startCommand(body["command"] as? String, taskIdentifier: taskIdentifier, reply: reply)
    case "write":
      if let taskIdentifier, let string = body["string"] as? String {
        tasks[taskIdentifier]?.write(string)
      }
      reply(nil, nil)
    default:
      reply(nil, "TextMate bridge: unknown method ‘\(method)’")
    }
  }

  private func startCommand(_ command: String?, taskIdentifier: Int?, reply: @escaping @MainActor (Any?, String?) -> Void) {
    guard let command, let taskIdentifier else {
      return reply(nil, "TextMate.system: missing command")
    }

    let task = ShellCommand(command: command, environment: environment)
    tasks[taskIdentifier] = task

    task.streamHandler = { [weak self] text, isError in
      self?.emit(taskIdentifier: taskIdentifier, which: isError ? "error" : "output", text: text)
    }
    task.completionHandler = { [weak self] output, error, status in
      self?.tasks[taskIdentifier] = nil
      reply(["outputString": output, "errorString": error, "status": status], nil)
    }

    if !task.start() {
      tasks[taskIdentifier] = nil
      reply(nil, "TextMate.system: unable to run ‘\(command)’")
    }
  }

  /// Streaming runs the other way, so it goes back through the page rather than a reply.
  private func emit(taskIdentifier: Int, which: String, text: String) {
    guard let json = try? JSONSerialization.data(withJSONObject: [taskIdentifier, which, text]),
      let arguments = String(data: json, encoding: .utf8)
    else { return }
    webView?.evaluateJavaScript("window.__tmBridgeEmit && window.__tmBridgeEmit.apply(null, \(arguments));", completionHandler: nil)
  }
}

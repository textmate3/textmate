import AppKit
import WebKit

/// Keeps a streaming command's output pinned to the bottom while the person has not scrolled away from it.
///
/// The page renders in another process and exposes no document view to observe from here, so the rule is expressed
/// inside the page: watch the document for mutations, and if the viewport was already at the bottom before the
/// mutation, put it back there afterwards.
@MainActor
private final class AutoScroll {
  private static let script = """
    (function() {
      if (window.__tmAutoScroll) return;
      var threshold = 2;
      var atBottom = function() {
        var doc = document.documentElement;
        return (window.innerHeight + window.scrollY) >= (doc.scrollHeight - threshold);
      };
      var wasAtBottom = true;
      var observer = new MutationObserver(function() {
        if (wasAtBottom) window.scrollTo(0, document.documentElement.scrollHeight);
        wasAtBottom = atBottom();
      });
      window.addEventListener('scroll', function() { wasAtBottom = atBottom(); });
      observer.observe(document.documentElement, { childList: true, subtree: true, characterData: true });
      window.__tmAutoScroll = observer;
    })();
    """

  init(webView: WKWebView) {
    webView.evaluateJavaScript(Self.script, completionHandler: nil)
  }
}

/// The status bar already has the two properties the JavaScript bridge sets. This says so to the compiler.
/// The bridge calls on the main thread, which the isolated conformance states.
extension HOStatusBar: @MainActor HOJSBridgeDelegate {}

/// Where a command's HTML output appears: a browser view that knows the command it is showing,
/// answers to the title binding, stops the command when asked, and acts on the links the page's own loader cannot.
@objc(OakHTMLOutputView)
@MainActor
public final class HTMLOutputView: BrowserView {
  /// The UUID from the initial load request, which is how the command that produced the page is found again.
  @objc public var commandIdentifier: UUID?

  /// Whether the command is still running. KVO compliant, since the output window binds its edited mark to it.
  @objc public dynamic private(set) var runningCommand = false
  @objc public var isRunningCommand: Bool { runningCommand }

  /// Whether the view is in a window. KVO compliant, since a command's refresher watches it.
  @objc public dynamic private(set) var visible = false
  @objc public var isVisible: Bool { visible }

  /// Whether a later command may take this view over. A refresher turns it off while it holds the view.
  @objc public var reusable = true
  @objc public var isReusable: Bool { reusable }

  @objc public var disableJavaScriptAPI = false

  private var autoScroll: AutoScroll?
  private var environment: [String: String] = [:]
  private var loadedRequest: URLRequest?
  private var bridge: HOJSBridge?

  @objc public static func keyPathsForValuesAffectingMainFrameTitle() -> Set<String> {
    ["webView.title"]
  }

  /// The page's title, or the command's name until the page has one. KVO compliant, since the output window binds its title to it.
  @objc public dynamic var mainFrameTitle: String {
    if let title = webView.title, !title.isEmpty {
      return title
    }
    if let request = loadedRequest {
      return URLProtocol.property(forKey: "processName", in: request) as? String ?? ""
    }
    return ""
  }

  @objc public func loadRequest(_ request: URLRequest, environment: [String: String], autoScrolls: Bool) {
    if autoScrolls {
      autoScroll = AutoScroll(webView: webView)
    }

    self.environment = environment
    installJavaScriptBridgeIfNeeded()
    bridge?.setEnvironmentDictionary(environment)
    commandIdentifier = URLProtocol.property(forKey: "commandIdentifier", in: request) as? UUID
    runningCommand = commandIdentifier != nil

    loadedRequest = request

    willChangeValue(forKey: "mainFrameTitle")
    webView.load(request)
    didChangeValue(forKey: "mainFrameTitle")
  }

  /// Stops the command behind the page, asking first when told to. The handler hears whether it stopped.
  @objc(stopLoadingWithUserInteraction:completionHandler:)
  public func stopLoading(askingUser: Bool, completionHandler: @escaping @MainActor @Sendable (Bool) -> Void) {
    guard let request = loadedRequest, let command = URLProtocol.property(forKey: "command", in: request) else {
      return completionHandler(true)
    }

    var alert: NSAlert?
    if askingUser {
      let processName = URLProtocol.property(forKey: "processName", in: request) as? String ?? ""
      let asking = NSAlert()
      asking.messageText = "Stop “\(processName)”?"
      asking.informativeText = "The job that the task is performing will not be completed."
      asking.addButton(withTitle: "Stop")
      asking.addButton(withTitle: "Cancel")
      alert = asking
    }

    // The command announces its end on the main queue, which is where the sheet and the handler belong.
    nonisolated(unsafe) var token: NSObjectProtocol?
    let alertWindow = alert?.window
    token = NotificationCenter.default.addObserver(forName: Notification.Name("OakCommandDidTerminateNotification"), object: command, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated {
        if let alertWindow, let window = self?.window {
          window.endSheet(alertWindow, returnCode: .alertFirstButtonReturn)
        }
        completionHandler(true)
        if let token {
          NotificationCenter.default.removeObserver(token)
        }
      }
    }

    if let alert, let window {
      alert.beginSheetModal(for: window) { [weak self] response in
        if response == .alertFirstButtonReturn {
          self?.webView.stopLoading()
        } else {
          completionHandler(false)
          if let token {
            NotificationCenter.default.removeObserver(token)
          }
        }
      }
    } else {
      webView.stopLoading()
    }
  }

  /// The view that should take keyboard focus when the output is shown. The web view, returned as a plain view
  /// so that the web engine stays an implementation detail.
  @objc public var contentView: NSView {
    webView
  }

  /// Folds the output away the way a page calling window.close() does, through the user interface delegate.
  @objc public func closeAsIfRequestedByPage() {
    webView.uiDelegate?.webViewDidClose?(webView)
  }

  @objc public func setContent(_ html: String) {
    webView.loadHTMLString(html, baseURL: URL(fileURLWithPath: NSHomeDirectory()))
  }

  public override func viewDidMoveToWindow() {
    NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
    if let window {
      NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)), name: NSWindow.willCloseNotification, object: window)
    }
    visible = window != nil
  }

  @objc private func windowWillClose(_ notification: Notification) {
    visible = false
  }

  // MARK: Navigation delegate

  public override func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    statusBar.isBusy = true
    setUpdatesProgress(!runningCommand)
  }

  /// User scripts and message handlers belong to the web view's configuration rather than to a navigation,
  /// so this runs once and the TextMate object is then present on every page the view loads.
  private func installJavaScriptBridgeIfNeeded() {
    guard bridge == nil, !disableJavaScriptAPI else { return }

    let bridge = HOJSBridge()
    bridge.delegate = statusBar
    bridge.webView = webView
    self.bridge = bridge

    let controller = webView.configuration.userContentController
    controller.addScriptMessageHandler(bridge, contentWorld: .page, name: HOJSBridge.messageHandlerName())
    controller.addUserScript(WKUserScript(source: HOJSBridge.userScriptSource(), injectionTime: .atDocumentStart, forMainFrameOnly: true))
  }

  public override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    runningCommand = false
    autoScroll = nil

    // After a redirect to a PDF the window has no first responder, so the first view under the
    // middle of the web view that will take it does.
    if let window, window.firstResponder === window {
      let rect = webView.frame
      var view: NSView? = webView.hitTest(NSPoint(x: rect.midX, y: rect.midY))
      while let candidate = view {
        if candidate.acceptsFirstResponder {
          window.makeFirstResponder(candidate)
          break
        }
        view = candidate.superview
      }
    }

    // The scroll position is not restored across reloads. The content lives in another process, so there is
    // no visible rect to read: it means asking the page for window.scrollY and setting it back through JavaScript.

    super.webView(webView, didFinish: navigation)
  }

  public override func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    runningCommand = false
    autoScroll = nil
    super.webView(webView, didFailProvisionalNavigation: navigation, withError: error)
  }

  public override func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    runningCommand = false
    autoScroll = nil
    super.webView(webView, didFail: navigation, withError: error)
  }

  /// Anything the loader can fetch itself, including this view's own scheme, is left to it.
  /// The rest is a link the page wants the application to act on: a txmt link goes to the application
  /// with the project added, and anything else to the system.
  public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
    guard var url = navigationAction.request.url else { return decisionHandler(.allow) }

    if NSURLConnection.canHandle(navigationAction.request) || url.scheme == FileHandleSchemeHandler.scheme {
      return decisionHandler(.allow)
    }

    decisionHandler(.cancel)

    if url.scheme == "txmt" {
      if let projectUUID = environment["TM_PROJECT_UUID"], let withProject = URL(string: url.absoluteString + "&project=\(projectUUID)") {
        url = withProject
      }
      NSApp.sendAction(Selector(("handleTxMtURL:")), to: nil, from: url)
    } else {
      NSWorkspace.shared.open(url)
    }
  }

  // MARK: Printing

  @IBAction public func printDocument(_ sender: Any?) {
    let operation = NSPrintOperation(view: webView)
    operation.printPanel.options.formUnion([.showsPaperSize, .showsOrientation])

    let info = operation.printInfo
    let display = info.imageablePageBounds.intersection(NSRect(origin: .zero, size: info.paperSize))
    info.leftMargin = display.minX
    info.rightMargin = info.paperSize.width - display.maxX
    info.topMargin = info.paperSize.height - display.maxY
    info.bottomMargin = display.minY

    guard let window else { return }
    operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
  }
}

import AppKit
import WebKit

/// The dummy protocol that makes `tm-file` URLs ones the loader says it can handle, so a link to one is left to it.
private final class TMFileDummyProtocol: URLProtocol {
  static let registration: Void = {
    URLProtocol.registerClass(TMFileDummyProtocol.self)
  }()

  override static func canInit(with request: URLRequest) -> Bool {
    request.url?.scheme == "tm-file"
  }

  override static func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override static func requestIsCacheEquivalent(_ first: URLRequest, to second: URLRequest) -> Bool {
    false
  }
}

/// What a page asks of the application through WebKit: alerts, confirmations, an open panel, a new window, and closing itself.
///
/// The status bar previewed a link's target while the pointer was over it, through the legacy delegate's
/// `setStatusText:` and `mouseDidMoveOverElement:`. `WKUIDelegate` has neither, so that preview is gone.
/// Reinstating it means a script that reports mouseover events.
@objc(HOWebViewDelegateHelper)
@MainActor
final class WebViewUIDelegate: NSObject, WKUIDelegate {
  private static let defaultURLProtocolKey = "defaultURLProtocol"

  /// Set once a page has closed its view, which tells the owner the next command needs a fresh one.
  @objc var needsNewWebView = false

  override init() {
    super.init()
    UserDefaults.standard.register(defaults: [Self.defaultURLProtocolKey: "https"])
    _ = TMFileDummyProtocol.registration
  }

  func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Script Message", comment: "JavaScript alert title")
    alert.informativeText = message
    alert.addButton(withTitle: NSLocalizedString("OK", comment: "JavaScript alert confirmation"))
    guard let window = webView.window else { return }
    await alert.beginSheetModal(for: window)
  }

  func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async -> Bool {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Script Message", comment: "JavaScript alert title")
    alert.informativeText = message
    alert.addButton(withTitle: NSLocalizedString("OK", comment: "JavaScript alert confirmation"))
    alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "JavaScript alert cancel"))
    guard let window = webView.window else { return false }
    return await alert.beginSheetModal(for: window) == .alertFirstButtonReturn
  }

  func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo) async -> [URL]? {
    let panel = NSOpenPanel()
    panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
    panel.allowsMultipleSelection = parameters.allowsMultipleSelection
    guard let window = webView.window else { return nil }
    return await panel.beginSheetModal(for: window) == .OK ? panel.urls : nil
  }

  /// A page opening a window gets one of its own, with a browser view inside, cascaded from the opener.
  /// Returning the new view is what tells WebKit to load the navigation into it. Nothing else has to request the load.
  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    var origin = NSPoint.zero
    if let opener = webView.window {
      origin = opener.cascadeTopLeft(from: NSPoint(x: opener.frame.minX, y: opener.frame.maxY))
      origin.y -= opener.frame.height
    }

    let view = BrowserView(frame: .zero)
    let window = NSWindow(contentRect: NSRect(origin: origin, size: NSSize(width: 750, height: 800)), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
    window.bind(.title, to: view.webView, withKeyPath: "title", options: nil)
    window.contentView = view
    window.makeKeyAndOrderFront(self)

    // The window owns itself until it closes, the way the Objective-C did with a bridging retain.
    _ = Unmanaged.passRetained(window)
    window.isReleasedWhenClosed = true

    return view.webView
  }

  func webViewDidClose(_ webView: WKWebView) {
    if !webView.tryToPerform(Selector(("toggleHTMLOutput:")), with: self) {
      webView.tryToPerform(#selector(NSWindow.performClose(_:)), with: self)
    }
    needsNewWebView = true
  }

  // There is no hook for rewriting arbitrary subresource requests. Link clicks can be intercepted, in the
  // navigation delegate, which the output view implements. The requests a page makes for its own assets cannot.
}

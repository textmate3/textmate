import AppKit
import WebKit

private func escapeHTML(_ string: String) -> String {
  string
    .replacingOccurrences(of: "&", with: "&amp;")
    .replacingOccurrences(of: "<", with: "&lt;")
    .replacingOccurrences(of: "\"", with: "&quot;")
}

/// The page shown when a load fails: the error, and the address as a link that opens it outside, revealed in Finder for a file.
@MainActor
private func showLoadError(in webView: WKWebView, for url: URL?, error: Error) {
  let address = escapeHTML(url?.absoluteString ?? "")
  let options = url?.scheme == "file" ? " -R" : ""
  let message = """
    <title>Load Error</title><h1>Load Error</h1>\
    <p>WebKit reported <em>\(escapeHTML(error.localizedDescription))</em> while loading \
    <tt><a href="#" onClick="javascript:TextMate.system('/usr/bin/open\(options) &quot;\(address)&quot;', null)">\(address)</a></tt>.</p>
    """
  webView.loadHTMLString(message, baseURL: URL(fileURLWithPath: NSTemporaryDirectory()))
}

/// A web view with the status bar under it, and the navigation and user interface delegates it needs.
/// The output view builds on it, and a page that opens a window gets a bare one.
@objc(HOBrowserView)
@MainActor
open class BrowserView: NSView, WKNavigationDelegate {
  @objc public let webView: WKWebView
  @objc public let statusBar: HOStatusBar

  private let uiDelegate = WebViewUIDelegate()
  private var progressObservation: NSKeyValueObservation?

  @objc public var needsNewWebView: Bool {
    uiDelegate.needsNewWebView
  }

  public override init(frame: NSRect) {
    let configuration = WKWebViewConfiguration()
    configuration.setURLSchemeHandler(HOFileHandleSchemeHandler(), forURLScheme: HOFileHandleURLScheme)
    webView = WKWebView(frame: .zero, configuration: configuration)
    statusBar = HOStatusBar(frame: .zero)
    super.init(frame: frame)

    statusBar.delegate = webView
    webView.navigationDelegate = self
    webView.uiDelegate = uiDelegate

    for view in [webView, statusBar] {
      view.translatesAutoresizingMaskIntoConstraints = false
      addSubview(view)
    }
    let views: [String: Any] = ["webView": webView, "statusBar": statusBar]
    addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[webView(>=10)]|", metrics: nil, views: views))
    addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[webView(>=10)][statusBar]|", options: [.alignAllLeft, .alignAllRight], metrics: nil, views: views))
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("BrowserView is created in code")
  }

  deinit {
    MainActor.assumeIsolated {
      progressObservation = nil
      webView.navigationDelegate = nil
      webView.uiDelegate = nil
      webView.stopLoading()
    }
  }

  /// The legacy web view announced progress through three notifications. There is no equivalent,
  /// so the property the notifications were reporting on is observed instead.
  @objc public func setUpdatesProgress(_ flag: Bool) {
    guard flag != (progressObservation != nil) else { return }
    if flag {
      progressObservation = webView.observe(\.estimatedProgress) { [weak self] webView, _ in
        MainActor.assumeIsolated {
          self?.statusBar.progress = webView.estimatedProgress
        }
      }
    } else {
      progressObservation = nil
    }
  }

  // MARK: Key events

  // The web view is typically the first responder, so a key event travels webView, BrowserView, HTMLOutputView, NSWindow,
  // and a key equivalent travels the same chain the other way around. The web view passes every key event, potential
  // key equivalents included, to the page, and there is no telling whether the page handled it, so the event goes on
  // down the chain regardless. To avoid the beep at the end of the responder chain this view swallows key events, and
  // to avoid handing an equivalent back to the web view without its modifier it ends the key equivalent chain too.
  // When no view in the hierarchy returns true, the key equivalent goes on to the menus, which is what should happen.

  public override func performKeyEquivalent(with event: NSEvent) -> Bool {
    false
  }

  public override func keyDown(with event: NSEvent) {
  }

  // MARK: Swipe

  public override func wantsScrollEventsForSwipeTracking(on axis: NSEvent.GestureAxis) -> Bool {
    axis == .horizontal
  }

  public override func scrollWheel(with event: NSEvent) {
    guard NSEvent.isSwipeTrackingFromScrollEventsEnabled, event.phase != [], abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return }

    let webView = webView
    event.trackSwipeEvent(options: [], dampenAmountThresholdMin: webView.canGoForward ? -1 : 0, max: webView.canGoBack ? 1 : 0) { gestureAmount, phase, _, _ in
      guard phase == .ended else { return }
      if gestureAmount > 0, webView.canGoBack {
        webView.goBack(self)
      } else if gestureAmount < 0, webView.canGoForward {
        webView.goForward(self)
      }
    }
  }

  // MARK: Navigation delegate

  public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    statusBar.isBusy = true
    setUpdatesProgress(true)
  }

  public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    let url = (error as NSError).userInfo[NSURLErrorFailingURLErrorKey] as? URL ?? webView.url
    showLoadError(in: webView, for: url, error: error)
    self.webView(webView, didFinish: navigation)
  }

  public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    let url = (error as NSError).userInfo[NSURLErrorFailingURLErrorKey] as? URL ?? webView.url
    showLoadError(in: webView, for: url, error: error)
    self.webView(webView, didFinish: navigation)
  }

  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    statusBar.canGoBack = webView.canGoBack
    statusBar.canGoForward = webView.canGoForward
    statusBar.isBusy = false
    statusBar.progress = 0
  }
}

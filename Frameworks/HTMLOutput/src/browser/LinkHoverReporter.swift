import WebKit

/// The status bar previews a link's target while the pointer is over it. The legacy web view reported that through
/// its delegate, and `WKUIDelegate` does not, so a script in the page reports it instead: the link under the pointer
/// on every mouse over, and nothing when the pointer leaves one.
@MainActor
final class LinkHoverReporter: NSObject, WKScriptMessageHandler {
  static let messageHandlerName = "textmateLinkHover"

  static let userScriptSource = """
    (function () {
      if (window.__tmLinkHover) return;
      window.__tmLinkHover = true;
      var post = function (href) { window.webkit.messageHandlers.textmateLinkHover.postMessage(href); };
      var linkAt = function (target) { return target && target.closest ? target.closest('a[href]') : null; };
      document.addEventListener('mouseover', function (event) {
        var link = linkAt(event.target);
        post(link ? link.href : '');
      }, true);
      document.addEventListener('mouseout', function (event) {
        if (linkAt(event.target)) post('');
      }, true);
    })();
    """

  weak var statusBar: HOStatusBar?

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    handle(message.body)
  }

  /// The link as the page sent it, shown decoded the way the legacy preview was, or nothing.
  func handle(_ body: Any) {
    let link = body as? String ?? ""
    statusBar?.statusText = link.removingPercentEncoding ?? link
  }
}

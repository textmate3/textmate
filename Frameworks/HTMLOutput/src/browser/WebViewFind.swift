import AppKit
import WebKit

/// Find, selection and view source for the web view in an output window.
///
/// The page renders in another process, so everything here is asynchronous: the selection comes back
/// through JavaScript, and searching goes through the web view's own find. The callers are all menu actions
/// and the find server, none of which need an answer inline. The selectors are the ones the menus send,
/// shared with the text view, so a page answers to the same Edit and Find menu items a document does.
extension WKWebView {
  private func selection(_ handler: @escaping @MainActor (String?) -> Void) {
    evaluateJavaScript("window.getSelection().toString()") { result, _ in
      let string = result as? String
      handler(string?.isEmpty == false ? string : nil)
    }
  }

  @objc(copySelectionToFindPboard:)
  public func copySelectionToFindPasteboard(_ sender: Any?) {
    selection { selection in
      guard let selection else { return NSSound.beep() }
      HOFindSupport.addFindPasteboardEntry(selection)
    }
  }

  @objc(copySelectionToReplacePboard:)
  public func copySelectionToReplacePasteboard(_ sender: Any?) {
    selection { selection in
      guard let selection else { return NSSound.beep() }
      HOFindSupport.addReplacePasteboardEntry(selection)
    }
  }

  private func findConfiguration(backwards: Bool, caseSensitive: Bool, wraps: Bool) -> WKFindConfiguration {
    let configuration = WKFindConfiguration()
    configuration.backwards = backwards
    configuration.caseSensitive = caseSensitive
    configuration.wraps = wraps
    return configuration
  }

  /// The Find window's search, sent down the responder chain. A page can be searched but not counted or replaced in,
  /// so anything else the window asks for is ignored.
  @objc(performFindOperation:)
  public func performFindOperation(_ findServer: Any) {
    guard let request = HOFindRequest(forFindServer: findServer) else { return }

    let configuration = findConfiguration(backwards: request.backwards, caseSensitive: !request.ignoresCase, wraps: request.wrapsAround)
    find(request.findString, configuration: configuration) { [weak self] result in
      guard result.matchFound, let self else {
        return request.reportFound(false, text: request.findString)
      }

      // Report what was actually matched, which needs one more hop to the page.
      self.selection { selection in
        request.reportFound(true, text: selection ?? request.findString)
      }
    }
  }

  private func findCurrentEntry(backwards: Bool) {
    guard let string = HOFindSupport.currentFindString() else { return }

    let configuration = findConfiguration(backwards: backwards, caseSensitive: !HOFindSupport.findIgnoresCase(), wraps: HOFindSupport.findWrapsAround())
    find(string, configuration: configuration) { _ in }
  }

  @objc(findNext:)
  public func findNext(_ sender: Any?) {
    findCurrentEntry(backwards: false)
  }

  @objc(findPrevious:)
  public func findPrevious(_ sender: Any?) {
    findCurrentEntry(backwards: true)
  }

  /// Asks the page for its own markup, which arrives already decoded, and opens it as a document.
  @objc(viewSource:)
  public func viewSource(_ sender: Any?) {
    evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
      guard let markup = result as? String else {
        let alert = NSAlert()
        alert.messageText = "Cannot Show Source"
        alert.informativeText = error?.localizedDescription ?? "The page did not return its markup."
        alert.addButton(withTitle: "Continue")
        alert.runModal()
        return
      }

      let title = self?.title
      HOFindSupport.showHTMLSource(markup, named: title?.isEmpty == false ? title : nil)
    }
  }
}

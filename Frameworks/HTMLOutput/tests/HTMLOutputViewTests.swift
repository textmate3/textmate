import AppKit
import Testing
import WebKit
@testable import HTMLOutput

/// The output view's face: what it says about the command it shows, before and after a load, without a window.
@Suite @MainActor struct HTMLOutputViewTests {
  private func request(commandIdentifier: UUID? = nil, processName: String? = nil) -> URLRequest {
    let mutable = NSMutableURLRequest(url: URL(string: "about:blank")!)
    if let commandIdentifier {
      URLProtocol.setProperty(commandIdentifier, forKey: "commandIdentifier", in: mutable)
    }
    if let processName {
      URLProtocol.setProperty(processName, forKey: "processName", in: mutable)
    }
    return mutable as URLRequest
  }

  @Test func startsReusableAndNotRunning() {
    let view = HTMLOutputView(frame: .zero)
    #expect(view.isReusable)
    #expect(!view.isRunningCommand)
    #expect(!view.isVisible)
    #expect(!view.needsNewWebView)
    #expect(view.commandIdentifier == nil)
    #expect(view.mainFrameTitle == "")
  }

  @Test func theContentViewIsTheWebView() {
    let view = HTMLOutputView(frame: .zero)
    #expect(view.contentView === view.webView)
    #expect(view.webView.superview === view)
  }

  @Test func aLoadWithACommandIdentifierIsARunningCommand() {
    let view = HTMLOutputView(frame: .zero)
    let identifier = UUID()
    view.loadRequest(request(commandIdentifier: identifier, processName: "Run Script"), environment: [:], autoScrolls: false)
    #expect(view.commandIdentifier == identifier)
    #expect(view.isRunningCommand)
  }

  @Test func aLoadWithoutACommandIdentifierIsNot() {
    let view = HTMLOutputView(frame: .zero)
    view.loadRequest(request(), environment: [:], autoScrolls: false)
    #expect(view.commandIdentifier == nil)
    #expect(!view.isRunningCommand)
  }

  @Test func theTitleFallsBackToTheCommandsNameUntilThePageHasOne() {
    let view = HTMLOutputView(frame: .zero)
    view.loadRequest(request(commandIdentifier: UUID(), processName: "Run Script"), environment: [:], autoScrolls: false)
    #expect(view.mainFrameTitle == "Run Script")
  }

  @Test func theTitleFollowsTheWebViewsTitle() {
    #expect(HTMLOutputView.keyPathsForValuesAffectingMainFrameTitle().contains("webView.title"))
  }

  @Test func stoppingWithNothingLoadedStopsAtOnce() async {
    let view = HTMLOutputView(frame: .zero)
    let stopped = await withCheckedContinuation { continuation in
      view.stopLoading(askingUser: false) { continuation.resume(returning: $0) }
    }
    #expect(stopped)
  }

  @Test func progressUpdatesCanBeTurnedOnAndOffRepeatedly() {
    let view = HTMLOutputView(frame: .zero)
    view.setUpdatesProgress(true)
    view.setUpdatesProgress(true)
    view.setUpdatesProgress(false)
    view.setUpdatesProgress(false)
    view.setUpdatesProgress(true)
  }
}

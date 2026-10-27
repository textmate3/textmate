import Testing
@testable import HTMLOutput

/// The link preview in the status bar, from what the page's script reports.
@Suite @MainActor struct LinkHoverReporterTests {
  @Test func aHoveredLinkShowsDecodedInTheStatusBar() {
    let statusBar = HOStatusBar(frame: .zero)
    let reporter = LinkHoverReporter()
    reporter.statusBar = statusBar

    reporter.handle("https://example.com/a%20file.html")
    #expect(statusBar.statusText == "https://example.com/a file.html")

    reporter.handle("")
    #expect(statusBar.statusText == "")
  }

  @Test func anythingButAStringClearsThePreview() {
    let statusBar = HOStatusBar(frame: .zero)
    statusBar.statusText = "stale"
    let reporter = LinkHoverReporter()
    reporter.statusBar = statusBar

    reporter.handle(42)
    #expect(statusBar.statusText == "")
  }
}

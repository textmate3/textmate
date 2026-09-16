import Testing
@testable import HTMLOutput

// The status strip decided which of two progress indicators to show by adding
// one to the view hierarchy and removing the other, so the decision could only
// be checked by looking at a window. It is a property now.

@MainActor
@Suite struct HTMLOutputStatusTests {
  @Test func noProgressMeansASpinner() {
    let status = HTMLOutputStatus()
    #expect(status.showsSpinner)
  }

  @Test func measurableProgressMeansABar() {
    let status = HTMLOutputStatus()
    status.progress = 0.5
    #expect(!status.showsSpinner)
  }

  @Test func aPageThatFinishesGoesBackToASpinner() {
    // The browser view sets progress to zero when a load ends, which is what
    // returns the strip to its idle shape.
    let status = HTMLOutputStatus()
    status.progress = 0.9
    status.progress = 0
    #expect(status.showsSpinner)
  }

  @Test func nothingIsNavigableUntilThereIsHistory() {
    let status = HTMLOutputStatus()
    #expect(!status.canGoBack)
    #expect(!status.canGoForward)
  }

  @Test func theStatusTextStartsEmpty() {
    #expect(HTMLOutputStatus().text.isEmpty)
  }

  @Test func theBarForwardsWhatTheObjectiveCPlusPlusSets() {
    // HOBrowserView sets these five by name. A rename here would compile and
    // then quietly do nothing, since Objective-C would find no such property.
    let bar = HOStatusBar(frame: .zero)
    bar.statusText = "https://example.com"
    bar.progress = 0.25
    bar.isBusy = true
    bar.canGoBack = true
    bar.canGoForward = true

    #expect(bar.statusText == "https://example.com")
    #expect(bar.progress == 0.25)
    #expect(bar.isBusy)
    #expect(bar.canGoBack)
    #expect(bar.canGoForward)
  }
}

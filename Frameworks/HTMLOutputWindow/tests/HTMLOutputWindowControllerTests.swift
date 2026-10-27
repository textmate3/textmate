import AppKit
import Testing
@testable import HTMLOutput
@testable import HTMLOutputWindow

/// The output window: what it is made of and what it decides, without showing it.
@Suite @MainActor struct HTMLOutputWindowControllerTests {
  @Test func theWindowHoldsTheOutputViewAndIsNotReleasedOnClose() throws {
    let controller = HTMLOutputWindowController()
    let window = try #require(controller.window)
    #expect(window.contentView === controller.htmlOutputView)
    #expect(window.delegate === controller)
    #expect(!window.isReleasedWhenClosed)
    #expect(window.collectionBehavior.contains(.moveToActiveSpace))
    #expect(window.collectionBehavior.contains(.fullScreenAuxiliary))
  }

  @Test func theTitleFollowsTheView() throws {
    let controller = HTMLOutputWindowController()
    let window = try #require(controller.window)
    let request = NSMutableURLRequest(url: URL(string: "about:blank")!)
    URLProtocol.setProperty("Run Script", forKey: "processName", in: request)
    controller.htmlOutputView.loadRequest(request as URLRequest, environment: [:], autoScrolls: false)
    #expect(window.title == "Run Script")
  }

  @Test func eachIdentifierRemembersItsOwnFrame() throws {
    let identifier = UUID()
    let controller = HTMLOutputWindowController(identifier: identifier)
    let window = try #require(controller.window)
    #expect(window.frameAutosaveName == "HTML output for \(identifier.uuidString)")
  }

  @Test func aWindowWithNoCommandRunningClosesAtOnce() throws {
    let controller = HTMLOutputWindowController()
    let window = try #require(controller.window)
    #expect(controller.windowShouldClose(window))
  }
}

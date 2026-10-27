import Foundation
import Testing
@testable import HTMLOutput

/// The scheme handler's asset policy: which paths a page may read, by the page it is and the directories registered for it.
@Suite @MainActor struct FileHandleSchemeHandlerTests {
  /// A directory of this test's own, with the files named inside it, gone when the test is.
  private struct Jail {
    let root: URL

    init() throws {
      root = FileManager.default.temporaryDirectory.appendingPathComponent("scheme-handler-\(UUID().uuidString)")
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func touch(_ relativePath: String) throws -> String {
      let url = root.appendingPathComponent(relativePath)
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      FileManager.default.createFile(atPath: url.path, contents: Data())
      return url.path
    }

    func path(_ relativePath: String) -> String {
      root.appendingPathComponent(relativePath).path
    }

    func remove() {
      try? FileManager.default.removeItem(at: root)
    }
  }

  private func pageURL(_ name: String) -> URL {
    URL(string: "\(FileHandleSchemeHandler.scheme)://job/\(name)")!
  }

  @Test func pageDirectoriesAreHonoredThroughTheMainDocumentURL() throws {
    let jail = try Jail()
    defer { jail.remove() }
    let picture = try jail.touch("project/notes/pic.png")
    let elsewhere = try jail.touch("elsewhere/x.png")

    let page = pageURL("test/1")
    FileHandleSchemeHandler.registerFileHandle(nil, processIdentifier: 0, allowedDirectories: [jail.path("project")], forURL: page)
    defer { FileHandleSchemeHandler.unregister(page) }

    let handler = FileHandleSchemeHandler()
    #expect(handler.isAssetPathAllowed(picture, forMainDocumentURL: page))
    #expect(!handler.isAssetPathAllowed(elsewhere, forMainDocumentURL: page))

    // A request that does not come from that page gets none of its directories.
    #expect(!handler.isAssetPathAllowed(picture, forMainDocumentURL: pageURL("other/2")))
    #expect(!handler.isAssetPathAllowed(picture, forMainDocumentURL: nil))
  }

  @Test func bundleLocationsAreAlwaysAllowed() {
    let handler = FileHandleSchemeHandler()
    let managed = ("~/Library/Application Support/TextMate 3/Managed/Bundles/Any.tmbundle/Support/style.css" as NSString).expandingTildeInPath
    #expect(handler.isAssetPathAllowed(managed, forMainDocumentURL: nil))
    #expect(!handler.isAssetPathAllowed("/etc/hosts", forMainDocumentURL: nil))
  }

  /// Images and scripts are requested after the page's output has finished, so the directories outlive the output
  /// and go away only when the page is unregistered.
  @Test func pageDirectoriesOutliveTheOutput() throws {
    let jail = try Jail()
    defer { jail.remove() }
    let picture = try jail.touch("project/pic.png")

    let page = pageURL("test/3")
    FileHandleSchemeHandler.registerFileHandle(nil, processIdentifier: 0, allowedDirectories: [jail.path("project")], forURL: page)
    FileHandleSchemeHandler.finish(page)

    let handler = FileHandleSchemeHandler()
    #expect(handler.isAssetPathAllowed(picture, forMainDocumentURL: page))

    FileHandleSchemeHandler.unregister(page)
    #expect(!handler.isAssetPathAllowed(picture, forMainDocumentURL: page))
  }
}

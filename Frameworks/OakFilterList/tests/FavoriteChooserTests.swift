import Foundation
import Testing
@testable import OakFilterList

/// The Open Recent Project window's two lists and its ordering, apart from the window.
@Suite @MainActor struct FavoriteChooserTests {
  /// A directory of this test's own, gone when the test is.
  private struct Jail {
    let root: URL

    init() throws {
      root = FileManager.default.temporaryDirectory.appendingPathComponent("favorites-\(UUID().uuidString)")
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func directory(_ relativePath: String) throws -> String {
      let url = root.appendingPathComponent(relativePath)
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
      return url.path
    }

    func link(_ relativePath: String, to destination: String) throws {
      try FileManager.default.createSymbolicLink(atPath: root.appendingPathComponent(relativePath).path, withDestinationPath: destination)
    }

    func path(_ relativePath: String) -> String {
      root.appendingPathComponent(relativePath).path
    }

    func remove() {
      try? FileManager.default.removeItem(at: root)
    }
  }

  @Test func recentProjectsComeNewestFirstThenByName() throws {
    let jail = try Jail()
    defer { jail.remove() }
    let older = try jail.directory("older")
    let newer = try jail.directory("newer")
    let alpha = try jail.directory("alpha")
    let gone = jail.path("gone")

    let items = FavoriteChooser.recentProjects(from: [
      ["key": older, "value": ["lastRecentlyUsed": Date(timeIntervalSince1970: 100)]],
      ["key": gone, "value": ["lastRecentlyUsed": Date(timeIntervalSince1970: 300)]],
      ["key": newer, "value": ["lastRecentlyUsed": Date(timeIntervalSince1970: 200)]],
      ["key": alpha, "value": ["lastRecentlyUsed": Date(timeIntervalSince1970: 100)]],
    ])
    #expect(items.map(\.path) == [newer, alpha, older])
    #expect(items.allSatisfy { $0.isRemovable })
  }

  @Test func favoritesAreTheLinksByNameWithDirectoryLinksExpanded() throws {
    let jail = try Jail()
    defer { jail.remove() }
    let favorites = try jail.directory("Favorites")
    let project = try jail.directory("checkouts/zebra")
    let clients = try jail.directory("work/clients")
    let one = try jail.directory("work/clients/one")
    let two = try jail.directory("work/clients/two")
    FileManager.default.createFile(atPath: jail.path("work/clients/notes.txt"), contents: Data())
    try jail.link("Favorites/zebra", to: project)
    try jail.link("Favorites/[DIR] customers", to: clients)
    FileManager.default.createFile(atPath: jail.path("Favorites/stray.txt"), contents: Data())

    let items = FavoriteChooser.favorites(inDirectory: favorites)
    #expect(items.map(\.displayName) == ["one", "two", "zebra"])
    #expect(items.map(\.path) == [one, two, project].map { ($0 as NSString).resolvingSymlinksInPath })
    #expect(items.map(\.isRemovable) == [false, false, true])
    // The link's name differs from its target's, so the rows say which folder they came through.
    #expect(items[0].displayNameSuffix == " — customers")
    #expect(items[2].link == jail.path("Favorites/zebra"))
  }

  /// The table asks its delegate, the chooser, through Objective-C. The base answers with a plain label and asks
  /// the item for a key it does not have, so the row has to come from the Swift override, reached by selector.
  @Test func theTableGetsItsRowsFromTheSwiftChooser() throws {
    let jail = try Jail()
    defer { jail.remove() }
    let chooser = FavoriteChooser()
    chooser.items = [FavoriteItem(path: try jail.directory("project"), isLink: false, isRemovable: true)]

    let column = try #require(chooser.tableView.tableColumns.first)
    let delegate = try #require(chooser.tableView.delegate)
    let view = delegate.tableView?(chooser.tableView, viewFor: column, row: 0)
    #expect(view is FileTableCellView)
  }

  @Test func withoutAFilterTheOrderIsKept() throws {
    let jail = try Jail()
    defer { jail.remove() }
    let items = try ["beta", "alpha"].map { FavoriteItem(path: try jail.directory($0), isLink: false, isRemovable: true) }
    #expect(FavoriteChooser.ranked(items, filter: "", bindings: []).map(\.displayName) == ["beta", "alpha"])
  }

  @Test func aFilterRanksByMatchWithEarlierPicksFirst() throws {
    let jail = try Jail()
    defer { jail.remove() }
    let items = try ["textmate", "tmbundle", "other"].map { FavoriteItem(path: try jail.directory($0), isLink: false, isRemovable: true) }

    let byMatch = FavoriteChooser.ranked(items, filter: "tm", bindings: [])
    #expect(byMatch.map(\.displayName) == ["tmbundle", "textmate"])

    let picked = FavoriteChooser.ranked(items, filter: "tm", bindings: [items[0].path])
    #expect(picked.map(\.displayName) == ["textmate", "tmbundle"])
    #expect(picked[0].name?.string == "textmate")
  }
}

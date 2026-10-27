import Foundation
import Testing
@testable import OakFilterList

/// Open Quickly apart from the window: how the typed filter is taken apart, how a row ranks, and what a pick carries.
@Suite @MainActor struct FileChooserTests {
  private func item(_ path: String, base: String = "/project", isCurrent: Bool = false) -> FileChooserItem {
    FileChooserItem(document: TMDocuments.document(withPath: path) as AnyObject, base: base, isCurrent: isCurrent)
  }

  @Test func aFilterIsAFilterAndAStarMakesItAGlob() {
    let filter = FileChooser.ParsedFilter.parse("Read Me")
    #expect(filter.filter == "readme")
    #expect(filter.glob == nil)

    let glob = FileChooser.ParsedFilter.parse("*.rb")
    #expect(glob.glob == "*.rb")
    #expect(glob.filter == nil)
  }

  @Test func aLineOrASymbolFollowsTheFileName() {
    let line = FileChooser.ParsedFilter.parse("main:12")
    #expect(line.filter == "main")
    #expect(line.selection == "12")
    #expect(line.symbol == nil)

    let range = FileChooser.ParsedFilter.parse("main:3:4-5:6")
    #expect(range.selection == "3:4-5:6")

    let symbol = FileChooser.ParsedFilter.parse("main@run")
    #expect(symbol.filter == "main")
    #expect(symbol.symbol == "run")
    #expect(symbol.listing == "main")
  }

  @Test func anEmptyFilterListsEverything() {
    #expect(FileChooser.ParsedFilter.parse(nil) == FileChooser.ParsedFilter())
    #expect(FileChooser.ParsedFilter.parse("").listing == "")
  }

  @Test func aRowKnowsItsFileAndItsDirectoryUnderTheProject() {
    let row = item("/project/lib/tm/editor.rb")
    #expect(row.file == "editor.rb")
    #expect(row.directory == "lib/tm")
    #expect(item("/project/Rakefile").directory == ".")
  }

  /// The document the person is already in goes last, since it is the one they are least likely to be looking for.
  @Test func withoutAFilterEverythingMatchesAndTheCurrentDocumentLast() {
    let other = item("/project/a.rb")
    let current = item("/project/b.rb", isCurrent: true)
    for row in [other, current] {
      row.updateRank(filter: "", bindings: [])
    }
    #expect(other.matched && current.matched)
    #expect(other.ranksBefore(current))
  }

  @Test func aNameMatchOutranksADirectoryMatchAndAMissDoesNotMatch() {
    let byName = item("/project/lib/editor.rb")
    let byDirectory = item("/project/edit/notes.txt")
    let miss = item("/project/lib/other.rb")
    for row in [byName, byDirectory, miss] {
      row.updateRank(filter: "edit", bindings: [])
    }
    #expect(byName.matched && byDirectory.matched)
    #expect(!miss.matched)
    #expect(byName.ranksBefore(byDirectory))
    #expect(byDirectory.isDirectoryMatched)
    #expect(!byName.isDirectoryMatched)
    #expect(byDirectory.folder.string == "edit")
    #expect(byName.name.string == "editor.rb")
  }

  @Test func aRememberedPickOutranksABetterNameMatch() {
    let exact = item("/project/edit.rb")
    let remembered = item("/project/editor_support.rb")
    for row in [exact, remembered] {
      row.updateRank(filter: "edit", bindings: ["/project/editor_support.rb"])
    }
    #expect(remembered.ranksBefore(exact))
  }

  @Test func aGlobMatchesByPathAlone() {
    let ruby = item("/project/lib/editor.rb")
    let text = item("/project/lib/notes.txt")
    let glob = TMGlob(pattern: "*.rb")
    ruby.updateRank(glob: glob)
    text.updateRank(glob: glob)
    #expect(ruby.matched)
    #expect(!text.matched)
  }

  @Test func aPickCarriesThePathAndTheLineTypedAfterIt() {
    let chooser = FileChooser()
    // The filter first, since setting it rebuilds the list from what the search found, which is nothing here.
    chooser.updateFilterString("editor:12")
    chooser.items = [item("/project/lib/editor.rb")]
    chooser.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

    let picked = chooser.selectedItems as? [[String: String]]
    #expect(picked == [["path": "/project/lib/editor.rb", "selectionString": "12"]])
  }

  @Test func theTableGetsItsRowsFromTheSwiftChooser() throws {
    let chooser = FileChooser()
    chooser.items = [item("/project/lib/editor.rb")]
    let column = try #require(chooser.tableView.tableColumns.first)
    let delegate = try #require(chooser.tableView.delegate)
    #expect(delegate.tableView?(chooser.tableView, viewFor: column, row: 0) is OakFileTableCellView)
  }
}

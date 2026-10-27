import Foundation
import Testing
@testable import OakFilterList

/// What every chooser shares, tried on the base alone: the items and their count, the selection across changes,
/// the filter reaching the search field, a pick reaching the target, and the default row.
@Suite @MainActor struct ChooserTests {
  /// A row the base's default cell can read by key.
  @objc private final class Row: NSObject {
    @objc let name: String
    init(_ name: String) { self.name = name }

    @objc(objectForKey:)
    func object(forKey key: String) -> Any? {
      key == "name" ? name : nil
    }
  }

  @MainActor @objc private final class Target: NSObject {
    var picked: [Any] = []

    @objc func chooserDidSelectItems(_ sender: Any?) {
      picked = (sender as? Chooser)?.selectedItems ?? []
    }
  }

  private func rows(_ names: String...) -> [Row] {
    names.map(Row.init)
  }

  @Test func theCountReadsAsItemsWithOneSingular() {
    #expect(Chooser.itemCountText(0) == "0 items")
    #expect(Chooser.itemCountText(1) == "1 item")
    #expect(Chooser.itemCountText(1234) == "1,234 items")
  }

  @Test func settingItemsSelectsTheFirstRowAndShowsTheCount() {
    let chooser = Chooser()
    chooser.items = rows("a", "b", "c")
    #expect(chooser.tableView.numberOfRows == 3)
    #expect(chooser.tableView.selectedRow == 0)
    #expect(chooser.itemCountTextField.stringValue == "3 items")
  }

  @Test func aSelectionBelowTheFirstRowFollowsItsItem() {
    let chooser = Chooser()
    let items = rows("a", "b", "c")
    chooser.items = items
    chooser.tableView.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)

    chooser.items = [items[2], items[0]]
    #expect(chooser.tableView.selectedRow == 0)
    #expect((chooser.selectedItems.first as? Row)?.name == "c")
  }

  @Test func removingRowsKeepsASelectionNearby() {
    let chooser = Chooser()
    chooser.items = rows("a", "b", "c")
    chooser.tableView.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)

    #expect(chooser.removeItems(at: IndexSet(integer: 2)) == 1)
    #expect(chooser.items.count == 2)
    #expect(chooser.tableView.numberOfRows == 2)
    #expect(chooser.tableView.selectedRow == 1)
    #expect(chooser.itemCountTextField.stringValue == "2 items")
  }

  @Test func theFilterReachesTheSearchFieldAndTheItems() {
    final class Counting: Chooser {
      var updates = 0
      override func updateItems(_ sender: Any?) { updates += 1 }
    }
    let chooser = Counting()
    chooser.filterString = "abc"
    #expect(chooser.searchField.stringValue == "abc")
    #expect(chooser.updates == 1)
    chooser.filterString = "abc"
    #expect(chooser.updates == 1)
  }

  @Test func acceptingTellsTheTargetWhichItemsWerePicked() {
    let chooser = Chooser()
    let target = Target()
    chooser.target = target
    chooser.action = #selector(Target.chooserDidSelectItems(_:))
    chooser.items = rows("a", "b")
    chooser.tableView.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)

    chooser.accept(nil)
    #expect((target.picked.first as? Row)?.name == "b")
  }

  @Test func theDefaultRowIsALabelWithTheItemsValueForTheColumn() throws {
    let chooser = Chooser()
    chooser.items = rows("only")
    let column = try #require(chooser.tableView.tableColumns.first)
    let view = chooser.tableView(chooser.tableView, viewFor: column, row: 0) as? NSTextField
    #expect(view?.stringValue == "only")
  }

}

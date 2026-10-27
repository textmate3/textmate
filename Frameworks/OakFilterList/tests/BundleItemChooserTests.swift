import Foundation
import Testing
@testable import OakFilterList

/// Select Bundle Item apart from the window: how a row ranks in each field, how a menu item's key reads, and what a
/// pick is remembered under.
@Suite @MainActor struct BundleItemChooserTests {
  private func item(_ name: String, location: String = "Ruby", uuid: String? = "A", value: String? = nil) -> BundleItemChooserItem {
    let item = BundleItemChooserItem()
    item.itemName = name
    item.location = location
    item.uuid = uuid
    item.value = value
    return item
  }

  private func rank(_ item: BundleItemChooserItem, _ filter: String, field: BundleItemField = .title, sources: BundleItemSearchSources = [.actions], bindings: [String] = []) {
    item.updateRank(filter: filter, field: field, sources: sources, bindings: bindings, defaultRank: 1)
  }

  @Test func aMenuItemsKeyReadsAsModifiersThenTheKey() {
    let save = NSMenuItem(title: "Save", action: nil, keyEquivalent: "s")
    save.keyEquivalentModifierMask = [.command]
    #expect(BundleItemChooser.keyEquivalent(for: save) == "@s")

    let all = NSMenuItem(title: "Select All", action: nil, keyEquivalent: "a")
    all.keyEquivalentModifierMask = [.command, .shift, .option]
    #expect(BundleItemChooser.keyEquivalent(for: all) == "~@A")

    let none = NSMenuItem(title: "Plain", action: nil, keyEquivalent: "")
    #expect(BundleItemChooser.keyEquivalent(for: none) == nil)
  }

  @Test func anActionRanksByNameFirstAndByLocationSecond() {
    let byName = item("Run Rake Task")
    let byLocation = item("Something Else", location: "Rake")
    let miss = item("Other", location: "Other")
    for row in [byName, byLocation, miss] {
      rank(row, "rake")
    }
    #expect(byName.matched && byLocation.matched)
    #expect(!miss.matched)
    #expect(byName.sortsBefore(byLocation))
    #expect(byName.name?.string == "Run Rake Task")
    #expect(byLocation.path?.string == "Rake")
  }

  @Test func aSettingMatchesBySubstringAndShowsItsValue() {
    let setting = item("tabSize", location: "Source ‣ Settings", value: "4")
    rank(setting, "TABS", sources: [.settings])
    #expect(setting.matched)
    #expect(setting.name?.string == "tabSize = 4")
  }

  @Test func theOtherFieldsMatchWholeOrContained() {
    let row = item("Run")
    row.keyEquivalent = "@r"
    row.tabTrigger = "run"
    row.semanticClass = "process.run"
    row.scopeSelector = "source.ruby"

    rank(row, "@r", field: .keyEquivalent)
    #expect(row.matched)
    rank(row, "@", field: .keyEquivalent)
    #expect(!row.matched)

    rank(row, "ru", field: .tabTrigger)
    #expect(row.matched)
    rank(row, "cess", field: .semanticClass)
    #expect(row.matched)
    rank(row, "ruby", field: .scopeSelector)
    #expect(row.matched)
    rank(row, "python", field: .scopeSelector)
    #expect(!row.matched)
  }

  @Test func aRememberedPickComesFirst() {
    let exact = item("Rake", uuid: "A")
    let remembered = item("Rake Task List", uuid: "B")
    for row in [exact, remembered] {
      rank(row, "rake", bindings: ["B"])
    }
    #expect(remembered.sortsBefore(exact))
  }

  @Test func anEclipsedRowIsStruckThrough() {
    let row = item("tabSize", value: "2")
    row.eclipsed = true
    rank(row, "tab", sources: [.settings])
    let attributes = row.name?.attributes(at: 0, effectiveRange: nil)
    #expect(attributes?[.strikethroughStyle] != nil)
  }

  @Test func aPickIsRememberedByUuidSelectorOrMenuItem() {
    #expect(item("Run", uuid: "A").identifier == "A")

    let binding = item("Move", uuid: nil)
    binding.action = #selector(NSResponder.moveForward(_:))
    #expect(binding.identifier == "moveForward:")

    let menuItem = NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
    menuItem.tag = 3
    let menu = item("Zoom", uuid: nil)
    menu.menuItem = menuItem
    #expect(menu.identifier == "zoom:3")
  }

  @Test func theScopeContextCarriesBothSides() {
    let context = TMScopeContext(left: "source.ruby string", right: "source.ruby")
    #expect(context.left == "source.ruby string")
    #expect(context.right == "source.ruby")
    #expect(TMScopeContext.wildcard.left == TMScopeContext.wildcard.right)
  }

  @Test func theTableGetsItsRowsFromTheSwiftChooser() throws {
    let chooser = BundleItemChooser()
    chooser.items = [item("Run")]
    let column = try #require(chooser.tableView.tableColumns.first)
    let delegate = try #require(chooser.tableView.delegate)
    #expect(delegate.tableView?(chooser.tableView, viewFor: column, row: 0) is BundleItemTableCellView)
  }
}

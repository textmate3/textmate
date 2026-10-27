import AppKit
import OSLog

/// One row of the Open Recent Project window: a project directory, recent or favorite, and how to show it.
/// The row's cell binds to the first four by key, so those are dynamic.
@objc final class FavoriteItem: NSObject {
  @objc dynamic let icon: NSImage
  @objc dynamic var name: NSAttributedString?
  @objc dynamic var folder: NSAttributedString?
  @objc dynamic let isRemovable: Bool

  /// The project's directory.
  @objc let path: String
  /// The symbolic link in the Favorites folder that names it, when it came from there.
  let link: String?
  let displayName: String
  /// The name of the folder a favorite was found through, when that folder's link is named differently.
  var displayNameSuffix: String?

  init(path: String, isLink: Bool, isRemovable: Bool) {
    var destination = path
    if isLink {
      do {
        destination = try FileManager.default.destinationOfSymbolicLink(atPath: path)
      } catch {
        Logger(subsystem: "com.textmate3.TextMate", category: "FavoriteChooser").error("Failed to read link: \(error.localizedDescription, privacy: .public)")
      }
    }
    self.path = destination
    link = isLink ? path : nil

    if isLink, (path as NSString).lastPathComponent != (destination as NSString).lastPathComponent {
      displayName = (path as NSString).lastPathComponent
    } else {
      displayName = FileManager.default.displayName(atPath: destination)
    }

    icon = NSWorkspace.shared.icon(forFile: destination)
    icon.size = NSSize(width: 32, height: 32)
    self.isRemovable = isRemovable
  }

  var displayNameWithSuffix: String {
    displayName + (displayNameSuffix ?? "")
  }
}

/// Open Recent Project: the projects opened before, or the ones in the Favorites folder, filtered as the person types.
/// Removing a row forgets a recent project or trashes a favorite's link.
@objc(FavoriteChooser)
@MainActor
public final class FavoriteChooser: OakChooser {
  @objc public static let sharedInstance = FavoriteChooser()

  enum Source: Int {
    case recentProjects = 0
    case favorites = 1
  }

  private static let sourceIndexKey = "openProjectSourceIndex"
  private static let bindingsName = "OakFavoriteChooserBindings"

  private let scopeBar = OakScopeBarViewController()
  private var originalItems: [FavoriteItem] = []

  /// Which list is shown, as the scope bar's index. The scope bar binds to it, so it is dynamic.
  @objc dynamic var sourceIndex: Int = NSNotFound {
    didSet {
      guard sourceIndex != oldValue else { return }
      loadItems()
      updateItems(self)
      UserDefaults.standard.set(sourceIndex, forKey: Self.sourceIndexKey)
    }
  }

  public override init() {
    super.init()
    window?.title = "Open Recent Project"
    tableView.allowsTypeSelect = false
    tableView.allowsMultipleSelection = true
    tableView.refusesFirstResponder = false
    tableView.rowHeight = 38

    scopeBar.labels = ["Recent Projects", "Favorites"]

    let titlebarViews: [String: NSView] = [
      "searchField": searchField,
      "dividerView": ChooserConstruction.separator(),
      "scopeBar": scopeBar.view,
    ]
    let titlebarView = NSView(frame: .zero)
    ChooserConstruction.addAutoLayoutViews(Array(titlebarViews.values), to: titlebarView)
    titlebarView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-(8)-[searchField]-(8)-|", metrics: nil, views: titlebarViews))
    titlebarView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[dividerView]|", metrics: nil, views: titlebarViews))
    titlebarView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-(8)-[scopeBar]-(>=8)-|", metrics: nil, views: titlebarViews))
    titlebarView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(4)-[searchField]-(8)-[dividerView(==1)]-(4)-[scopeBar]-(4)-|", metrics: nil, views: titlebarViews))
    addTitlebarAccessoryView(titlebarView)

    let footerViews: [String: NSView] = [
      "dividerView": ChooserConstruction.separator(),
      "statusTextField": statusTextField,
      "itemCountTextField": itemCountTextField,
    ]
    ChooserConstruction.addAutoLayoutViews(Array(footerViews.values), to: footerView)
    footerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[dividerView]|", metrics: nil, views: footerViews))
    footerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[statusTextField]-[itemCountTextField]-|", options: .alignAllCenterY, metrics: nil, views: footerViews))
    footerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[dividerView(==1)]-(4)-[statusTextField]-(5)-|", metrics: nil, views: footerViews))

    updateScrollViewInsets()

    ChooserConstruction.setUpKeyViewLoop([tableView, searchField, scopeBar.view])
    window?.initialFirstResponder = tableView

    sourceIndex = UserDefaults.standard.integer(forKey: Self.sourceIndexKey)
    scopeBar.bind(.value, to: self, withKeyPath: "sourceIndex", options: nil)
  }

  @IBAction public func selectNextTab(_ sender: Any?) {
    scopeBar.selectNextButton(sender)
  }

  @IBAction public func selectPreviousTab(_ sender: Any?) {
    scopeBar.selectPreviousButton(sender)
  }

  @objc public func updateShowTabMenu(_ menu: NSMenu) {
    scopeBar.updateGoToMenu(menu)
  }

  // MARK: Rows

  /// The row view: icon, name, folder and a remove button, the last hidden on a row that cannot be removed.
  /// The base implements this delegate method in a class extension Swift cannot see, so this is not an override
  /// to the compiler, and it has to be marked for Objective-C by hand to be the one the table calls.
  @objc public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let tableColumn else { return nil }
    let cell: NSTableCellView
    if let existing = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTableCellView {
      cell = existing
    } else {
      let removeImage = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
        NSColor.black.set()
        rect.insetBy(dx: 0, dy: floor(rect.height / 2) - 1).fill()
        return true
      }
      removeImage.isTemplate = true

      let removeButton = NSButton()
      removeButton.controlSize = .small
      removeButton.refusesFirstResponder = true
      removeButton.bezelStyle = .roundRect
      removeButton.setButtonType(.momentaryPushIn)
      removeButton.image = removeImage
      removeButton.target = self
      removeButton.action = #selector(takeItemToRemove(from:))

      cell = OakFileTableCellView(closeButton: removeButton)
      cell.identifier = tableColumn.identifier
      removeButton.bind(.hidden, to: cell, withKeyPath: "objectValue.isRemovable", options: [.valueTransformerName: NSValueTransformerName.negateBooleanTransformerName])
    }
    cell.objectValue = items[row]
    return cell
  }

  // MARK: Items

  /// The projects opened before, newest first and by name among equals, leaving out any that is gone from disk.
  static func recentProjects(from entries: [[AnyHashable: Any]]) -> [FavoriteItem] {
    let sorted = entries.sorted { lhs, rhs in
      let lhsDate = (lhs["value"] as? [String: Any])?["lastRecentlyUsed"] as? Date ?? .distantPast
      let rhsDate = (rhs["value"] as? [String: Any])?["lastRecentlyUsed"] as? Date ?? .distantPast
      if lhsDate != rhsDate {
        return lhsDate > rhsDate
      }
      let lhsName = ((lhs["key"] as? String ?? "") as NSString).lastPathComponent
      let rhsName = ((rhs["key"] as? String ?? "") as NSString).lastPathComponent
      return lhsName.localizedCompare(rhsName) == .orderedAscending
    }
    return sorted.compactMap { entry in
      guard let path = entry["key"] as? String, FileManager.default.fileExists(atPath: path) else { return nil }
      return FavoriteItem(path: path, isLink: false, isRemovable: true)
    }
  }

  /// The links in the Favorites folder, by name. A link named "[DIR] something" stands for every directory
  /// inside its target rather than for the target itself, and those cannot be removed from here.
  static func favorites(inDirectory favoritesPath: String) -> [FavoriteItem] {
    let fileManager = FileManager.default
    func kind(of path: String) -> FileAttributeType? {
      (try? fileManager.attributesOfItem(atPath: path))?[.type] as? FileAttributeType
    }

    var items: [FavoriteItem] = []
    for name in (try? fileManager.contentsOfDirectory(atPath: favoritesPath)) ?? [] {
      let linkPath = (favoritesPath as NSString).appendingPathComponent(name)
      guard kind(of: linkPath) == .typeSymbolicLink else { continue }

      if name.hasPrefix("[DIR] ") {
        let folderName = String(name.dropFirst(6))
        let path = (linkPath as NSString).resolvingSymlinksInPath
        let includeLinkName = (path as NSString).lastPathComponent != folderName
        for subname in (try? fileManager.contentsOfDirectory(atPath: path)) ?? [] {
          let subpath = (path as NSString).appendingPathComponent(subname)
          guard kind(of: subpath) == .typeDirectory else { continue }
          let item = FavoriteItem(path: subpath, isLink: false, isRemovable: false)
          item.displayNameSuffix = includeLinkName ? " — \(folderName)" : nil
          items.append(item)
        }
      } else {
        items.append(FavoriteItem(path: linkPath, isLink: true, isRemovable: true))
      }
    }
    return items.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
  }

  private func loadItems() {
    switch Source(rawValue: sourceIndex) {
    case .recentProjects:
      originalItems = Self.recentProjects(from: OakProjectStateStore.sharedInstance.allEntries)
    case .favorites:
      originalItems = Self.favorites(inDirectory: TMApplicationPaths.supportPath("Favorites"))
    case nil:
      originalItems = []
    }
  }

  public override func showWindow(_ sender: Any?) {
    if window?.isVisible != true {
      filterString = ""
      loadItems()
      updateItems(self)
      if tableView.numberOfRows > 0 {
        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
      }
    }
    super.showWindow(sender)
  }

  /// The items as the filter orders them. With no filter, the list as loaded. With one, by how well each name matches,
  /// except that an item picked before for this very filter comes first, the most recent pick foremost.
  static func ranked(_ items: [FavoriteItem], filter: String, bindings: [String]) -> [FavoriteItem] {
    var ranked: [(rank: Double, order: Int, item: FavoriteItem)] = []
    for item in items {
      var rank = Double(ranked.count)
      var byteRanges: [NSRange] = []
      if !filter.isEmpty {
        guard let match = TMRanker.rankFilter(filter, candidate: item.displayName) else { continue }
        byteRanges = match.byteRanges.map(\.rangeValue)
        if let bindingIndex = bindings.firstIndex(of: item.path) {
          rank = -1.0 * Double(bindings.count - bindingIndex)
        } else {
          rank = -match.score
        }
      }

      item.name = markedUpString(item.displayNameWithSuffix, byteRanges: byteRanges, lineBreakMode: .byTruncatingTail)
      let folder = ((item.path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath
      item.folder = markedUpString(folder, byteRanges: [], lineBreakMode: .byTruncatingHead)
      ranked.append((rank, ranked.count, item))
    }
    return ranked.sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.order < $1.order }.map(\.item)
  }

  public override func updateItems(_ sender: Any?) {
    let filter = (filterString ?? "").decomposedStringWithCanonicalMapping
    let bindings = OakAbbreviations.abbreviations(forName: Self.bindingsName).strings(forAbbreviation: filterString ?? "")
    items = Self.ranked(originalItems, filter: filter, bindings: bindings)
  }

  public override func updateStatusText(_ sender: Any?) {
    guard tableView.selectedRow != -1, let item = items[tableView.selectedRow] as? FavoriteItem else {
      statusTextField.stringValue = ""
      return
    }
    statusTextField.stringValue = (item.path as NSString).abbreviatingWithTildeInPath
  }

  // MARK: Accepting and removing

  public override func accept(_ sender: Any?) {
    let chosen = selectedItems.compactMap { $0 as? FavoriteItem }
    if let filterString {
      for item in chosen {
        OakAbbreviations.abbreviations(forName: Self.bindingsName).learn(abbreviation: filterString, forString: item.path)
      }
    }

    let store = OakProjectStateStore.sharedInstance
    for item in chosen {
      if var state = store.state(forProjectAtPath: item.path) {
        state["lastRecentlyUsed"] = Date()
        store.setState(state, forProjectAtPath: item.path)
      }
    }

    super.accept(sender)
  }

  public override func removeItems(at indexes: IndexSet) -> UInt {
    let items = self.items.compactMap { $0 as? FavoriteItem }
    let removable = indexes.filteredIndexSet { items[$0].isRemovable }

    for item in removable.map({ items[$0] }) {
      if let link = item.link {
        try? FileManager.default.trashItem(at: URL(fileURLWithPath: link), resultingItemURL: nil)
      } else {
        OakProjectStateStore.sharedInstance.removeState(forProjectAtPath: item.path)
      }
    }

    loadItems()
    return super.removeItems(at: removable)
  }

  @objc private func takeItemToRemove(from sender: NSButton) {
    let row = tableView.row(for: sender)
    if row != -1 {
      _ = removeItems(at: IndexSet(integer: row))
    }
  }

  // MARK: Keys

  public override func deleteForward(_ sender: Any?) {
    if removeItems(at: tableView.selectedRowIndexes) == 0 {
      NSSound.beep()
    }
  }

  public override func deleteBackward(_ sender: Any?) {
    let index = tableView.selectedRowIndexes.first
    if removeItems(at: tableView.selectedRowIndexes) == 0 {
      NSSound.beep()
    } else if let index, index > 0, tableView.numberOfRows > 0 {
      tableView.selectRowIndexes(IndexSet(integer: index - 1), byExtendingSelection: false)
    }
  }

  /// Typing on the table starts a filter: the text goes to the search field and the field takes focus with the caret at its end.
  public override func insertText(_ insertString: Any) {
    filterString = insertString as? String
    window?.makeFirstResponder(searchField)
    if let fieldEditor = window?.firstResponder as? NSText {
      fieldEditor.selectedRange = NSRange(location: fieldEditor.string.count, length: 0)
    }
  }

  public override func doCommand(by selector: Selector) {
    if responds(to: selector) {
      super.doCommand(by: selector)
      return
    }
    switch OakPerformTableViewActionFromSelector(tableView, selector) {
    case .moveAcceptReturn: accept(self)
    case .moveCancelReturn: cancel(self)
    default: break
    }
  }

  public override func keyDown(with event: NSEvent) {
    interpretKeyEvents([event])
  }

  public override func insertTab(_ sender: Any?) {
    window?.selectNextKeyView(self)
  }

  public override func insertBacktab(_ sender: Any?) {
    window?.selectPreviousKeyView(self)
  }
}

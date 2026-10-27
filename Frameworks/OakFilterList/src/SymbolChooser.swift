import AppKit

/// One row of the symbol chooser: a symbol in the document, where it is, and how to show it.
@objc final class SymbolChooserItem: NSObject {
  @objc let path: String?
  @objc let identifier: String
  /// The position as the editor's selection string, which is what the caller selects when the row is chosen.
  @objc let selectionString: String
  @objc let name: NSAttributedString
  @objc let infoString: String

  init(path: String?, identifier: String, selectionString: String, name: NSAttributedString, infoString: String) {
    self.path = path
    self.identifier = identifier
    self.selectionString = selectionString
    self.name = name
    self.infoString = infoString
  }

  /// The base chooser's table asks each item for its column by key.
  @objc(objectForKey:)
  func object(forKey key: String) -> Any? {
    switch key {
    case "identifier": return identifier
    case "infoString": return infoString
    case "name": return name
    case "path": return path
    case "selectionString": return selectionString
    default: return nil
    }
  }
}

/// Jump to Symbol: the document's symbols, filtered as the person types, with the one at the selection chosen to begin with.
@objc(SymbolChooser)
@MainActor
public final class SymbolChooser: OakChooser {
  @objc public static let sharedInstance = SymbolChooser()

  private static let title = "Jump to Symbol"

  /// The document whose symbols are listed. Untyped, since the document class is declared with C++ types the Swift cannot see.
  @objc(TMDocument) public var symbolDocument: AnyObject? {
    didSet {
      if symbolDocument != nil {
        updateItems(self)
      }
      window?.title = symbolDocument.map { "\(Self.title) — \(TMDocumentSymbols.displayName(ofDocument: $0))" } ?? Self.title
    }
  }

  /// The editor's selection. Setting it selects the symbol the selection is in.
  @objc public var selectionString: String? {
    didSet {
      selectRowForSelection()
    }
  }

  public override init() {
    super.init()
    window?.title = Self.title

    let titlebarView = NSView(frame: .zero)
    ChooserConstruction.addAutoLayoutViews([searchField], to: titlebarView)
    let titlebarViews = ["searchField": searchField]
    titlebarView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-(8)-[searchField]-(8)-|", metrics: nil, views: titlebarViews))
    titlebarView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(4)-[searchField]-(8)-|", metrics: nil, views: titlebarViews))
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
    window?.initialFirstResponder = searchField
  }

  @objc public func windowWillClose(_ notification: Notification) {
    symbolDocument = nil
  }

  /// The symbol the selection is in: the last symbol at or before the start of the selection's last range,
  /// with an earlier range's answer kept when a later range has none before it.
  static func indexOfSymbol(forRangeStarts starts: [TMTextPosition], amongPositions positions: [TMTextPosition]) -> Int? {
    var found: Int?
    for start in starts {
      let before = positions.lastIndex { $0.compare(start) != .orderedDescending }
      if let before {
        found = before
      }
    }
    return found
  }

  private func selectRowForSelection() {
    guard let selectionString, let items = items as? [SymbolChooserItem] else { return }
    let positions = items.map { TMDocumentSymbols.rangeStarts(inSelectionString: $0.selectionString).first ?? TMTextPosition() }
    let starts = TMDocumentSymbols.rangeStarts(inSelectionString: selectionString)
    guard let row = Self.indexOfSymbol(forRangeStarts: starts, amongPositions: positions) else { return }
    tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    tableView.scrollRowToVisible(row)
  }

  private func item(for symbol: TMDocumentSymbol, name: String, byteRanges: [NSRange]) -> SymbolChooserItem {
    guard let document = symbolDocument else { preconditionFailure("an item needs a document") }
    let selectionString = symbol.position.string
    return SymbolChooserItem(
      path: TMDocumentSymbols.path(ofDocument: document),
      identifier: TMDocumentSymbols.identifier(ofDocument: document),
      selectionString: selectionString,
      name: markedUpString(name, byteRanges: byteRanges, lineBreakMode: .byTruncatingTail),
      infoString: "\(TMDocumentSymbols.displayName(ofDocument: document)):\(selectionString)")
  }

  public override func updateItems(_ sender: Any?) {
    guard let document = symbolDocument else {
      items = []
      return
    }

    // A symbol named with a lone dash is a separator in the symbol list and not a place to jump to.
    let symbols = TMDocumentSymbols.symbols(inDocument: document).filter { $0.name != "-" }
    let filter = filterString ?? ""
    if filter.isEmpty {
      items = symbols.map { item(for: $0, name: $0.name, byteRanges: []) }
      return
    }

    // An indented symbol is shown with the section it sits under, so a match on either finds it.
    let normalized = TMRanker.normalizeFilter(filter)
    var sectionName: String?
    var ranked: [(score: Double, item: SymbolChooserItem)] = []
    for symbol in symbols {
      let indented = symbol.name.hasPrefix("\u{2003}")
      if !indented {
        sectionName = symbol.name
      }
      guard let match = TMRanker.rankFilter(normalized, candidate: symbol.name) else { continue }
      let name = indented && sectionName != nil ? "\(symbol.name) — \(sectionName ?? "")" : symbol.name
      ranked.append((match.score, item(for: symbol, name: name, byteRanges: match.byteRanges.map(\.rangeValue))))
    }
    items = ranked.sorted { $0.score > $1.score }.map(\.item)
  }

  public override func updateStatusText(_ sender: Any?) {
    guard let items = items as? [SymbolChooserItem], !items.isEmpty else {
      statusTextField.stringValue = ""
      return
    }
    let row = tableView.selectedRow == -1 ? 0 : tableView.selectedRow
    statusTextField.stringValue = items[row].infoString
  }
}

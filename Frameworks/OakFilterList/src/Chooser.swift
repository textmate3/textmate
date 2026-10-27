import AppKit

/// What the four choosers share: a floating panel with a search field in its title bar, a table of items under it, a
/// footer with the status and the item count, and the keys that move through the table while the field has focus.
///
/// A chooser lists items, ranks them as the filter changes, and tells its target through its action when one is
/// picked. The subclasses decide what the items are, how they rank, and what a row looks like.
@objc(OakChooser)
@MainActor
open class Chooser: NSWindowController, NSWindowDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
  /// Sent to the target with the chooser when an item is picked.
  @objc open var action: Selector?
  @objc open weak var target: AnyObject?

  /// What the person typed. The search field binds to it, so it is dynamic.
  @objc open dynamic var filterString: String? {
    didSet {
      guard filterString != oldValue else { return }
      searchField.stringValue = filterString ?? ""
      updateFilterString(filterString)
      // See https://lists.apple.com/archives/accessibility-dev/2014/Aug/msg00024.html
      NSAccessibility.post(element: tableView, notification: .selectedRowsChanged)
    }
  }

  /// The rows, in the order shown. Setting them keeps the selection on the same items where it can, else the first row.
  @objc open var items: [Any] = [] {
    didSet {
      if !removingRows {
        itemsDidChange(from: oldValue)
      }
    }
  }

  /// Set while rows are taken out one by one, when the table has already removed them and must not reload.
  private var removingRows = false

  @objc open var selectedItems: [Any] {
    tableView.selectedRowIndexes.map { items[$0] }
  }

  /// Whether the table draws its selection as active, which it does while the search field has focus and the table
  /// refuses it, so that the person sees the row their arrow keys move.
  @objc open var drawTableViewAsHighlighted = false {
    didSet {
      tableView.enumerateAvailableRowViews { rowView, _ in
        (rowView as? InactiveTableRowView)?.drawAsHighlighted = drawTableViewAsHighlighted
      }
    }
  }

  private var accessoryViewController: NSTitlebarAccessoryViewController?
  private var firstResponderObservation: NSKeyValueObservation?
  // MARK: Views

  @objc public let searchField: NSSearchField = OakLinkedSearchField(frame: .zero)
  @objc public let tableView = NSTableView(frame: .zero)
  @objc public let scrollView = NSScrollView(frame: .zero)
  @objc public let statusTextField = NSTextField(frame: .zero)
  /// The count, in a font whose digits are all one width so that it does not jiggle as the count changes.
  @objc public let itemCountTextField = NSTextField(frame: .zero)
  /// The footer floats over the bottom of the table, which is why the scroll view takes an inset for it.
  @objc public let footerView = NSVisualEffectView(frame: .zero)

  /// The views are made with the chooser and set up here, all of them, so that tearing down touches nothing that
  /// was never made.
  private func setUpViews() {
    searchField.cell?.isScrollable = true
    (searchField.cell as? NSSearchFieldCell)?.sendsSearchStringImmediately = true
    searchField.setAccessibilitySharedFocusElements([tableView])
    if !NSApp.isFullKeyboardAccessEnabled {
      searchField.focusRingType = .none
    }
    searchField.delegate = self
    searchField.bind(.value, to: self, withKeyPath: "filterString", options: nil)

    tableView.headerView = nil
    tableView.focusRingType = .none
    tableView.allowsEmptySelection = false
    tableView.allowsMultipleSelection = false
    tableView.refusesFirstResponder = true
    tableView.doubleAction = #selector(accept(_:))
    tableView.target = self
    tableView.dataSource = self
    tableView.delegate = self
    tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name")))

    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.borderType = .noBorder
    scrollView.documentView = tableView

    for field in [statusTextField, itemCountTextField] {
      field.isBezeled = false
      field.isBordered = false
      field.drawsBackground = false
      field.isEditable = false
      field.isSelectable = false
      field.font = ChooserConstruction.statusBarFont()
    }
    statusTextField.cell?.lineBreakMode = .byTruncatingMiddle
    statusTextField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    statusTextField.setContentHuggingPriority(.defaultLow, for: .horizontal)

    itemCountTextField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    let countFont = ChooserConstruction.statusBarFont()
    let descriptor = countFont.fontDescriptor.addingAttributes([
      .featureSettings: [[NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType, NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector]]
    ])
    itemCountTextField.font = NSFont(descriptor: descriptor, size: 0) ?? countFont

    footerView.blendingMode = .withinWindow
    footerView.material = .headerView

    guard let contentView = window?.contentView else { return }
    contentView.wantsLayer = true
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    footerView.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(scrollView, positioned: .below, relativeTo: nil)
    contentView.addSubview(footerView, positioned: .above, relativeTo: nil)
    let views = ["scrollView": scrollView, "footerView": footerView]
    contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[scrollView]|", metrics: nil, views: views))
    contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[scrollView]|", metrics: nil, views: views))
    contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(>=77)-[footerView]|", metrics: nil, views: views))
    contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[footerView]|", metrics: nil, views: views))
  }

  // MARK: Setting up

  /// A chooser builds its own panel: floating, with the window buttons it does not need hidden, and its frame
  /// remembered under the subclass's name. The window initializer is the designated one, since a window controller's
  /// plain initializer is a convenience Swift cannot make designated, and nil asks for the panel.
  public convenience init() {
    self.init(window: nil)
  }

  public override init(window: NSWindow?) {
    let panel = window ?? NSPanel(contentRect: NSRect(x: 600, y: 700, width: 400, height: 500), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    super.init(window: panel)

    panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
    panel.standardWindowButton(.zoomButton)?.isHidden = true
    panel.level = .floating
    panel.setFrameAutosaveName(NSStringFromClass(type(of: self)))
    panel.delegate = self
    setUpViews()

    firstResponderObservation = panel.observe(\.firstResponder, options: [.old, .new]) { [weak self] _, change in
      MainActor.assumeIsolated {
        self?.firstResponderDidChange(from: change.oldValue ?? nil, to: change.newValue ?? nil)
      }
    }
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("A chooser is created in code")
  }

  deinit {
    MainActor.assumeIsolated {
      searchField.delegate = nil
      searchField.unbind(.value)
      firstResponderObservation = nil
      tableView.target = nil
      tableView.dataSource = nil
      tableView.delegate = nil
    }
  }

  @objc open func addTitlebarAccessoryView(_ titlebarView: NSView) {
    titlebarView.translatesAutoresizingMaskIntoConstraints = false
    let controller = NSTitlebarAccessoryViewController()
    controller.view = titlebarView
    controller.view.setFrameSize(titlebarView.fittingSize)
    accessoryViewController = controller
    window?.addTitlebarAccessoryViewController(controller)
  }

  @objc open func updateScrollViewInsets() {
    var insets = scrollView.contentInsets
    insets.bottom += footerView.fittingSize.height
    scrollView.automaticallyAdjustsContentInsets = false
    scrollView.contentInsets = insets
  }

  // MARK: Showing

  /// Showing an already key chooser closes it, so the same key toggles it.
  open override func showWindow(_ sender: Any?) {
    if let window, isWindowLoaded, window.isVisible, window.isKeyWindow {
      window.close()
      return
    }
    window?.makeFirstResponder(window?.initialFirstResponder)
    super.showWindow(sender)
  }

  /// Shows the chooser a quarter of the way in from the left of the frame and a quarter down from its top,
  /// which is where the eye is on an editor window.
  @objc(showWindowRelativeToFrame:)
  open func showWindow(relativeTo parentFrame: NSRect) {
    if let window, !window.isVisible {
      window.layoutIfNeeded()
      var frame = window.frame
      frame.origin.x = parentFrame.minX + ((parentFrame.width - frame.width) * 1 / 4).rounded()
      frame.origin.y = parentFrame.minY + ((parentFrame.height - frame.height) * 3 / 4).rounded()
      window.setFrame(frame, display: false)
    }
    showWindow(self)
  }

  /// The table draws as active while the search field, or its field editor, has focus. A subclass with another
  /// view standing in for the field extends this.
  open func firstResponderDidChange(from oldResponder: NSResponder?, to newResponder: NSResponder?) {
    let oldIsSearchField = oldResponder === searchField || oldResponder === searchField.currentEditor()
    let newIsSearchField = newResponder === searchField || newResponder === searchField.currentEditor()
    if oldIsSearchField != newIsSearchField {
      drawTableViewAsHighlighted = newIsSearchField && tableView.refusesFirstResponder
    }
  }

  // MARK: Keys

  /// Arrow keys and the like typed in the search field move the table's selection. Return accepts and escape cancels.
  public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    let result = OakPerformTableViewActionFromSelector(tableView, commandSelector)
    switch result {
    case .moveAcceptReturn: performDefaultButtonClick(self)
    case .moveCancelReturn: cancel(self)
    default: break
    }
    return result != .moveNoActionReturn
  }

  // MARK: Items

  /// Called with the new filter. Selects the first row and asks the subclass for the items, which a subclass may
  /// extend to read the filter its own way first.
  @objc open func updateFilterString(_ string: String?) {
    if tableView.numberOfRows != 0 {
      tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
      tableView.scrollRowToVisible(0)
    }
    updateItems(self)
  }

  private func itemsDidChange(from oldItems: [Any]) {
    let oldSelectedRows = tableView.selectedRowIndexes
    var selectedItems: [AnyObject] = []
    if oldSelectedRows.count > 1 || (oldSelectedRows.count == 1 && oldSelectedRows.first != 0) {
      selectedItems = oldSelectedRows.compactMap { $0 < oldItems.count ? oldItems[$0] as AnyObject : nil }
    }

    tableView.reloadData()

    var rows = IndexSet()
    for item in selectedItems {
      if let row = items.firstIndex(where: { ($0 as AnyObject) === item }) {
        rows.insert(row)
      }
    }
    if rows.isEmpty {
      rows.insert(0)
    }

    tableView.selectRowIndexes(rows, byExtendingSelection: false)
    if !UserDefaults.standard.bool(forKey: "disableFilterListAutoScroll"), let first = rows.first {
      tableView.scrollRowToVisible(first)
    }

    updateStatusText(self)
    itemCountTextField.stringValue = Self.itemCountText(items.count)
  }

  static func itemCountText(_ count: Int) -> String {
    let number = NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal)
    return "\(number) item\(count == 1 ? "" : "s")"
  }

  /// Takes the rows out with a fade, keeping a selection where one was. Answers how many went.
  @objc(removeItemsAtIndexes:)
  @discardableResult
  open func removeItems(at indexes: IndexSet) -> UInt {
    tableView.removeRows(at: indexes, withAnimation: .effectFade)
    var remaining = items
    for index in indexes.reversed() where index < remaining.count {
      remaining.remove(at: index)
    }
    removingRows = true
    items = remaining
    removingRows = false
    itemCountTextField.stringValue = Self.itemCountText(items.count)

    if tableView.numberOfRows > 0, tableView.selectedRowIndexes.isEmpty, let first = indexes.first {
      tableView.selectRowIndexes(IndexSet(integer: min(first, tableView.numberOfRows - 1)), byExtendingSelection: false)
    }
    return UInt(indexes.count)
  }

  // MARK: Actions

  @objc open func performDefaultButtonClick(_ sender: Any?) {
    if let defaultButtonCell = window?.defaultButtonCell {
      defaultButtonCell.performClick(sender)
    } else {
      accept(sender)
    }
  }

  /// Hides the chooser, tells the target, and closes.
  @objc open func accept(_ sender: Any?) {
    window?.orderOut(self)
    if let action {
      NSApp.sendAction(action, to: target, from: self)
    }
    window?.close()
  }

  @objc open func cancel(_ sender: Any?) {
    window?.performClose(self)
  }

  // MARK: Table

  public func numberOfRows(in tableView: NSTableView) -> Int {
    items.count
  }

  public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
    InactiveTableRowView()
  }

  public func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
    (rowView as? InactiveTableRowView)?.drawAsHighlighted = drawTableViewAsHighlighted
  }

  /// A plain label with the item's value for the column, by key. A subclass with richer rows overrides this.
  open func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let tableColumn else { return nil }
    let label: NSTextField
    if let existing = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTextField {
      label = existing
    } else {
      label = ChooserConstruction.label(font: .controlContentFont(ofSize: 0))
      label.identifier = tableColumn.identifier
    }
    let item = items[row] as AnyObject
    let value = item.perform(#selector(NSDictionary.object(forKey:)), with: tableColumn.identifier.rawValue)?.takeUnretainedValue()
    label.objectValue = value
    return label
  }

  public func tableViewSelectionDidChange(_ notification: Notification) {
    updateStatusText(self)
  }

  // MARK: Overridden by each chooser

  /// Rebuilds the items from the filter string.
  @objc open func updateItems(_ sender: Any?) {
  }

  /// The status text for the selected row.
  @objc open func updateStatusText(_ sender: Any?) {
    statusTextField.stringValue = ""
  }

  open func windowWillClose(_ notification: Notification) {
  }
}

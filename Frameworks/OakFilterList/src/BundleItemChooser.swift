import AppKit

/// Select Bundle Item: every command, snippet, setting, grammar, theme, menu item and key binding that applies where the
/// caret is, searched by title, key equivalent, tab trigger, semantic class or scope selector. A pick runs the item, or
/// opens it for editing.
@objc(BundleItemChooser)
@MainActor
public final class BundleItemChooser: OakChooser, NSMenuItemValidation {
  @objc public static let sharedInstance = BundleItemChooser()

  private static let bindingsName = "OakBundleItemChooserBindings"

  private var titlebarView = NSView(frame: .zero)
  private var layoutConstraints: [NSLayoutConstraint] = []
  private let actionsPopUpButton = ChooserConstruction.actionPopUpButton(bordered: true)
  private let scopeBar = OakScopeBarViewController()
  private let topDivider = ChooserConstruction.separator()
  private let bottomDivider = ChooserConstruction.separator()
  private let selectButton = ChooserConstruction.button("Select")
  private let editButton = ChooserConstruction.button("Edit")
  private var keyEquivalentView: OakKeyEquivalentView?
  private var recordingObservation: NSKeyValueObservation?
  private var eventMonitor: Any?

  private var unfilteredItems: [BundleItemChooserItem]?
  private var searchSources: BundleItemSearchSources = [.actions, .menuItems, .keyBindings] {
    didSet {
      guard searchSources != oldValue else { return }
      unfilteredItems = nil
      updateItems(self)
    }
  }
  private var bundleItemField = BundleItemField.title {
    didSet {
      guard bundleItemField != oldValue else { return }
      keyEquivalentInput = bundleItemField == .keyEquivalent
      filterString = nil
      updateItems(self)
    }
  }
  private var keyEquivalentInput = false {
    didSet {
      guard keyEquivalentInput != oldValue else { return }
      swapSearchInput()
    }
  }
  private var searchAllScopes = false

  /// The key equivalent being recorded, bound to the recording view.
  @objc dynamic var keyEquivalentString: String? {
    didSet {
      guard keyEquivalentString != oldValue else { return }
      updateItems(self)
    }
  }

  /// Which tab is shown, as the scope bar's index. The scope bar binds to it, so it is dynamic.
  @objc dynamic var sourceIndex: Int = 0 {
    didSet {
      switch sourceIndex {
      case 0: searchSources = [.actions, .menuItems, .keyBindings]
      case 1: searchSources = [.settings]
      case 2: searchSources = [.grammars, .themes]
      default: break
      }
    }
  }

  /// The document the settings tab answers for.
  @objc public var path: String?
  @objc public var directory: String?

  /// The scope at the caret, which decides which items apply.
  @objc public var scope: TMScopeContext = .wildcard {
    didSet {
      unfilteredItems = nil
      updateItems(self)
    }
  }

  @objc public var hasSelection = false {
    didSet {
      guard hasSelection != oldValue else { return }
      unfilteredItems = nil
      updateItems(self)
    }
  }

  /// Sent to the target with the chooser when the person asks to edit the item rather than run it.
  @objc public var editAction: Selector?

  public override init() {
    super.init()
    tableView.rowHeight = 38
    window?.title = "Select Bundle Item"

    let actionMenu = actionsPopUpButton.menu ?? NSMenu()
    actionsPopUpButton.menu = actionMenu
    actionMenu.addItem(withTitle: "Placeholder", action: nil, keyEquivalent: "")

    let fields: [(title: String, field: BundleItemField)] = [
      ("Title", .title),
      ("Key Equivalent", .keyEquivalent),
      ("Tab Trigger", .tabTrigger),
      ("Semantic Class", .semanticClass),
      ("Scope Selector", .scopeSelector),
    ]

    // The first two fields and the scope toggle get number keys, the way the Objective-C numbered them.
    var key = 0
    actionMenu.addItem(withTitle: "Search", action: Selector(("nop:")), keyEquivalent: "")
    for info in fields {
      var keyEquivalent = ""
      if key < 2 {
        key += 1
        keyEquivalent = String(key % 10)
      }
      let item = actionMenu.addItem(withTitle: info.title, action: #selector(takeBundleItemField(from:)), keyEquivalent: keyEquivalent)
      item.indentationLevel = 1
      item.tag = info.field.rawValue
    }

    actionMenu.addItem(.separator())
    var scopeKeyEquivalent = ""
    if key < 9 {
      key += 1
      scopeKeyEquivalent = String(key % 10)
    }
    actionMenu.addItem(withTitle: "Search All Scopes", action: #selector(toggleSearchAllScopes(_:)), keyEquivalent: scopeKeyEquivalent)

    scopeBar.labels = ["Actions", "Settings", "Other"]

    for button in [selectButton, editButton] {
      button.font = .messageFont(ofSize: NSFont.systemFontSize(for: .small))
      button.controlSize = .small
      button.target = self
    }
    selectButton.action = #selector(accept(_:))
    editButton.action = #selector(editItem(_:))

    ChooserConstruction.addAutoLayoutViews([searchField, actionsPopUpButton, topDivider, scopeBar.view], to: titlebarView)
    setUpLayoutConstraints()
    addTitlebarAccessoryView(titlebarView)

    let footerViews: [String: NSView] = [
      "dividerView": bottomDivider,
      "status": statusTextField,
      "edit": editButton,
      "select": selectButton,
    ]
    ChooserConstruction.addAutoLayoutViews(Array(footerViews.values), to: footerView)
    footerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[dividerView]|", metrics: nil, views: footerViews))
    footerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-(24)-[status]-(>=0)-[edit]-[select]-|", options: .alignAllCenterY, metrics: nil, views: footerViews))
    footerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[dividerView(==1)]-(4)-[select]-(5)-|", metrics: nil, views: footerViews))

    updateScrollViewInsets()

    ChooserConstruction.setUpKeyViewLoop([searchField, actionsPopUpButton, scopeBar.view, editButton, selectButton])
    window?.initialFirstResponder = searchField

    scopeBar.bind(.value, to: self, withKeyPath: "sourceIndex", options: nil)
    if let window {
      NotificationCenter.default.addObserver(self, selector: #selector(windowDidChangeKeyStatus(_:)), name: NSWindow.didBecomeKeyNotification, object: window)
      NotificationCenter.default.addObserver(self, selector: #selector(windowDidChangeKeyStatus(_:)), name: NSWindow.didResignKeyNotification, object: window)
    }
  }

  deinit {
    MainActor.assumeIsolated {
      NotificationCenter.default.removeObserver(self)
      scopeBar.unbind(.value)
    }
  }

  /// The default button is Select when the row can run, and Edit when it can only be edited or the option key is
  /// down, which a local event monitor watches for while the window is key.
  @objc private func windowDidChangeKeyStatus(_ notification: Notification) {
    let updateDefaultButton: (NSEvent?) -> Void = { [weak self] event in
      guard let self, let window else { return }
      let isKeyWindow = NSApp.keyWindow == window
      let optionDown = event.map { $0.modifierFlags.intersection(.deviceIndependentFlagsMask) == .option } ?? false
      window.defaultButtonCell = canEdit && (!canAccept || (optionDown && isKeyWindow)) ? editButton.cell as? NSButtonCell : selectButton.cell as? NSButtonCell
    }

    updateDefaultButton(NSApp.currentEvent)
    if NSApp.keyWindow == window {
      eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
        MainActor.assumeIsolated { updateDefaultButton(event) }
        return event
      }
    } else if let eventMonitor {
      NSEvent.removeMonitor(eventMonitor)
      self.eventMonitor = nil
    }
  }

  /// The base watches the window's first responder to draw the table as active while the search field has focus.
  /// When the key equivalent view stands in for the field, the same goes for it, unless it is recording.
  public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
    super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)

    // The window reports its first responder on the main thread, which the isolated block states. The two
    // responders are taken as identities first, since the change dictionary cannot cross into it.
    guard keyPath == "firstResponder" else { return }
    let oldResponder = (change?[.oldKey] as AnyObject?).map(ObjectIdentifier.init)
    let newResponder = (change?[.newKey] as AnyObject?).map(ObjectIdentifier.init)
    MainActor.assumeIsolated {
      guard let keyEquivalentView, !keyEquivalentView.recording else { return }
      let oldIsKeyEquivalentView = oldResponder == ObjectIdentifier(keyEquivalentView)
      let newIsKeyEquivalentView = newResponder == ObjectIdentifier(keyEquivalentView)
      if oldIsKeyEquivalentView != newIsKeyEquivalentView {
        drawTableViewAsHighlighted = newIsKeyEquivalentView
      }
    }
  }

  private func setUpLayoutConstraints() {
    let titlebarViews: [String: NSView] = [
      "searchField": keyEquivalentInput ? (keyEquivalentView ?? searchField) : searchField,
      "actions": actionsPopUpButton,
      "dividerView": topDivider,
      "scopeBar": scopeBar.view,
    ]

    var constraints: [NSLayoutConstraint] = []
    constraints += NSLayoutConstraint.constraints(withVisualFormat: "H:|-(8)-[searchField(>=50)]-[actions]-(8)-|", options: .alignAllCenterY, metrics: nil, views: titlebarViews)
    constraints += NSLayoutConstraint.constraints(withVisualFormat: "H:|[dividerView]|", metrics: nil, views: titlebarViews)
    constraints += NSLayoutConstraint.constraints(withVisualFormat: "H:|-(8)-[scopeBar]-(>=8)-|", metrics: nil, views: titlebarViews)
    constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|-(4)-[searchField]-(8)-[dividerView(==1)]-(4)-[scopeBar]-(4)-|", metrics: nil, views: titlebarViews)
    titlebarView.addConstraints(constraints)
    layoutConstraints = constraints
  }

  public override func showWindow(_ sender: Any?) {
    bundleItemField = .title
    if tableView.numberOfRows > 0 {
      tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
      tableView.scrollRowToVisible(0)
    }
    super.showWindow(sender)
  }

  /// The base declares the delegate conformance in a class extension Swift cannot see, so this is a new method
  /// to the compiler, under the selector the window sends.
  @objc public func windowWillClose(_ notification: Notification) {
    unfilteredItems = nil
    items = []
  }

  public override func keyDown(with event: NSEvent) {
    switch OakPerformTableViewActionFromKeyEvent(tableView, event) {
    case .moveAcceptReturn: performDefaultButtonClick(self)
    case .moveCancelReturn: cancel(self)
    default: break
    }
  }

  // MARK: Key equivalent input

  /// The view that records a key equivalent in the search field's place, made when first needed.
  private func makeKeyEquivalentView() -> OakKeyEquivalentView {
    if let keyEquivalentView { return keyEquivalentView }
    let view = OakKeyEquivalentView(frame: .zero)
    view.translatesAutoresizingMaskIntoConstraints = false
    view.bind(.value, to: self, withKeyPath: "keyEquivalentString", options: nil)
    recordingObservation = view.observe(\.recording, options: .new) { [weak self] _, change in
      MainActor.assumeIsolated {
        self?.drawTableViewAsHighlighted = !(change.newValue ?? false)
      }
    }
    view.setAccessibilitySharedFocusElements([tableView])
    keyEquivalentView = view
    return view
  }

  private func replace(_ oldView: NSView, with newView: NSView) {
    let next = oldView.nextKeyView
    let previous = oldView.previousKeyView

    let contentView = oldView.superview
    oldView.removeFromSuperview()
    contentView?.addSubview(newView)

    previous?.nextKeyView = newView
    newView.nextKeyView = next

    newView.window?.initialFirstResponder = newView
    newView.window?.makeFirstResponder(newView)
  }

  private func swapSearchInput() {
    titlebarView.removeConstraints(layoutConstraints)
    layoutConstraints = []

    let keyEquivalentView = makeKeyEquivalentView()
    if keyEquivalentInput {
      replace(searchField, with: keyEquivalentView)
    } else {
      replace(keyEquivalentView, with: searchField)
    }

    setUpLayoutConstraints()

    keyEquivalentView.eventString = nil
    keyEquivalentView.recording = keyEquivalentInput

    updateItems(self)
  }

  @objc private func toggleSearchAllScopes(_ sender: Any?) {
    searchAllScopes.toggle()
    unfilteredItems = nil
    updateItems(self)
  }

  @objc private func takeBundleItemField(from sender: Any?) {
    if let item = sender as? NSMenuItem, let field = BundleItemField(rawValue: item.tag) {
      bundleItemField = field
    }
  }

  // MARK: Rows

  /// The base implements this delegate method in a class extension Swift cannot see, so this is not an override
  /// to the compiler, and it has to be marked for Objective-C by hand, under the delegate's own selector, to be the
  /// one the table calls.
  @objc(tableView:viewForTableColumn:row:)
  public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let tableColumn else { return nil }
    let cell: NSTableCellView
    if let existing = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTableCellView {
      cell = existing
    } else {
      cell = BundleItemTableCellView()
      cell.identifier = tableColumn.identifier
    }
    cell.objectValue = items[row]
    return cell
  }

  // MARK: Items

  /// The key equivalent a menu item shows, in the bundle notation: modifier symbols then the key, with shift folded
  /// into an uppercase letter.
  static func keyEquivalent(for menuItem: NSMenuItem) -> String? {
    guard !menuItem.keyEquivalent.isEmpty else { return nil }

    let eventFlags: [(flag: NSEvent.ModifierFlags, symbol: String)] = [
      (.numericPad, "#"),
      (.control, "^"),
      (.option, "~"),
      (.shift, "$"),
      (.command, "@"),
    ]

    var key = menuItem.keyEquivalent
    var flags = menuItem.keyEquivalentModifierMask
    if flags.contains(.shift) {
      let upcased = key.uppercased()
      if key != upcased {
        flags.remove(.shift)
        key = upcased
      }
    }

    let modifiers = eventFlags.filter { flags.contains($0.flag) }.map(\.symbol).joined()
    return modifiers + key
  }

  /// Every item in the menus a target answers for and allows, with its path of parent titles, leaving out the ones
  /// that stand for bundle items and themes, which the bundle index lists on its own.
  private static func menuItems(in menu: NSMenu, parentNames: [String] = []) -> [(name: String, path: String, menuItem: NSMenuItem)] {
    let excludedActions: Set<Selector> = [
      Selector(("performBundleItemWithUUIDStringFrom:")),
      Selector(("takeThemeAppearanceFrom:")),
      Selector(("takeUniversalThemeUUIDFrom:")),
      Selector(("takeDarkThemeUUIDFrom:")),
    ]

    var result: [(name: String, path: String, menuItem: NSMenuItem)] = []
    for item in menu.items {
      if let action = item.action, excludedActions.contains(action) {
        continue
      }

      if let action = item.action, let target = NSApp.target(forAction: action) as AnyObject? {
        let allowed = (target as? NSMenuItemValidation)?.validateMenuItem(item) ?? true
        if allowed {
          var title = item.title
          if item.state == .on {
            title += item.onStateImage?.name() == "NSMenuItemBullet" ? " (•)" : " (✓)"
          }
          result.append((title, parentNames.joined(separator: " ‣ "), item))
        }
      }

      if let submenu = item.submenu {
        if submenu.title == "Spelling", let delegate = submenu.delegate {
          delegate.menuNeedsUpdate?(submenu)
        }
        result += menuItems(in: submenu, parentNames: parentNames + [item.title])
      }
    }
    return result
  }

  private func buildUnfilteredItems() -> [BundleItemChooserItem] {
    var items: [BundleItemChooserItem] = []
    let scope = searchAllScopes ? TMScopeContext.wildcard : self.scope
    let bundleEditorClass: AnyClass? = NSClassFromString("BundleEditor")

    for record in TMBundleItems.records(inScope: scope, hasSelection: hasSelection, sources: searchSources.bundleItemSources, everyScope: searchAllScopes) {
      let item = BundleItemChooserItem()
      item.itemName = record.name
      item.location = record.location
      item.uuid = record.uuid
      item.scopeSelector = record.scopeSelector
      item.keyEquivalent = record.keyEquivalent
      item.tabTrigger = record.tabTrigger
      item.semanticClass = record.semanticClass
      item.value = record.value
      item.eclipsed = record.eclipsed
      item.kindName = record.isSettings ? "Settings" : TMBundleItems.kindName(ofItemWithUUID: record.uuid)
      if let kindName = item.kindName, let bundleEditorClass {
        item.icon = NSImage(named: kindName, inSameBundleAsClass: bundleEditorClass)
      }
      items.append(item)
    }

    // A key bound in a menu is not listed again from a key bindings file for the same action.
    var seen = Set<String>()
    if searchSources.contains(.menuItems), let mainMenu = NSApp.mainMenu {
      for record in Self.menuItems(in: mainMenu) {
        let item = BundleItemChooserItem()
        item.itemName = record.name
        item.location = record.path
        item.menuItem = record.menuItem
        item.keyEquivalent = Self.keyEquivalent(for: record.menuItem)
        if let keyEquivalent = item.keyEquivalent, let action = record.menuItem.action {
          seen.insert(keyEquivalent + "\u{0}" + NSStringFromSelector(action))
        }
        if let bundleEditorClass {
          item.icon = NSImage(named: "MenuItem", inSameBundleAsClass: bundleEditorClass)
        }
        items.append(item)
      }
    }

    if searchSources.contains(.keyBindings) {
      var keysSeen = Set<String>()
      for record in TMBundleItems.keyBindingRecords() {
        var name = record.name
        if let selectorName = record.selectorName {
          if !seen.insert(record.keyEquivalent + "\u{0}" + selectorName).inserted {
            continue
          }
          if NSApp.target(forAction: NSSelectorFromString(selectorName)) == nil {
            name += " (unknown action)"
          }
        }

        let item = BundleItemChooserItem()
        item.itemName = name
        item.location = record.location
        item.file = record.file
        item.keyEquivalent = record.keyEquivalent
        item.eclipsed = !keysSeen.insert(record.keyEquivalent).inserted
        item.action = record.selectorName.map(NSSelectorFromString)
        item.icon = TMBundleItems.icon(forFile: record.file)
        items.append(item)
      }
    }

    if searchSources.contains(.settings) {
      for record in TMBundleItems.settings(forPath: path, scope: scope, everyScope: searchAllScopes, directory: directory) {
        let item = BundleItemChooserItem()
        item.itemName = record.name
        item.value = record.value
        item.location = record.location
        item.file = record.file
        item.line = record.line
        item.icon = record.file.map(TMBundleItems.icon(forFile:)) ?? NSImage(systemSymbolName: "dollarsign.circle", accessibilityDescription: "Preferences")
        items.append(item)
      }
    }

    return items
  }

  public override func updateItems(_ sender: Any?) {
    let bindings = OakAbbreviations.abbreviations(forName: Self.bindingsName).strings(forAbbreviation: filterString ?? "")
    let filter = (keyEquivalentInput ? keyEquivalentString : filterString) ?? ""

    let items = unfilteredItems ?? buildUnfilteredItems()
    unfilteredItems = items

    // Settings keep the order they apply in, and so does a key equivalent search, since the first binding wins.
    let preserveOrder = searchSources.contains(.settings) || (bundleItemField == .keyEquivalent && !filter.isEmpty)
    let field = bundleItemField
    let sources = searchSources
    DispatchQueue.concurrentPerform(iterations: items.count) { index in
      let rank = preserveOrder ? Double(items.count - index) / Double(items.count) : 1
      items[index].updateRank(filter: filter, field: field, sources: sources, bindings: bindings, defaultRank: rank)
    }

    self.items = items.filter(\.matched).sorted { $0.sortsBefore($1) }
    window?.title = "Select Bundle Item (\(itemCountTextField.stringValue))"
  }

  private var selectedItem: BundleItemChooserItem? {
    tableView.selectedRow == -1 ? nil : items[tableView.selectedRow] as? BundleItemChooserItem
  }

  /// The status line shows what the row answers to. The base asks for it on every selection change, which is also
  /// when the two buttons learn whether the row can run or be edited.
  public override func updateStatusText(_ sender: Any?) {
    let item = selectedItem
    statusTextField.stringValue = item?.semanticClass ?? item?.scopeSelector ?? item?.action.map { NSStringFromSelector($0) } ?? ""

    selectButton.isEnabled = canAccept
    editButton.isEnabled = canEdit
    window?.defaultButtonCell = !canAccept && canEdit ? editButton.cell as? NSButtonCell : selectButton.cell as? NSButtonCell
    tableView.doubleAction = !canAccept && canEdit ? #selector(editItem(_:)) : #selector(accept(_:))
  }

  public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    if menuItem.action == #selector(takeBundleItemField(from:)) {
      menuItem.state = bundleItemField.rawValue == menuItem.tag ? .on : .off
    } else if menuItem.action == #selector(toggleSearchAllScopes(_:)) {
      menuItem.state = searchAllScopes ? .on : .off
    }
    return true
  }

  /// A row can run when it is a menu item, a key binding with an action, or a bundle item other than settings.
  private var canAccept: Bool {
    guard let item = selectedItem else { return false }
    return item.menuItem != nil || item.action != nil || (item.uuid != nil && item.kindName != "Settings")
  }

  /// A row can be edited when it is a bundle item and there is an edit action, or when it comes from a file.
  private var canEdit: Bool {
    guard let item = selectedItem else { return false }
    return (item.uuid != nil && editAction != nil) || item.file != nil
  }

  // MARK: Actions

  /// Runs the row: a menu item or key binding through its own action, anything else by telling the target.
  /// A title search that found the row other than first, or with more than one character, is remembered for it.
  public override func accept(_ sender: Any?) {
    if bundleItemField == .title, let filterString, !filterString.isEmpty, tableView.selectedRow > 0 || filterString.count > 1, let identifier = selectedItem?.identifier {
      OakAbbreviations.abbreviations(forName: Self.bindingsName).learn(abbreviation: filterString, forString: identifier)
    }

    if let item = selectedItem {
      var action: Selector?
      var target: AnyObject?
      var from: Any? = self

      if let menuItem = item.menuItem {
        target = menuItem.target
        action = menuItem.action
        from = menuItem
      } else {
        action = item.action
      }

      if let action {
        window?.orderOut(self)
        NSApp.sendAction(action, to: target, from: from)
        window?.close()
        return
      }
    }

    super.accept(sender)
  }

  @IBAction public func editItem(_ sender: Any?) {
    guard canEdit, let editAction else { return NSSound.beep() }
    window?.orderOut(self)
    NSApp.sendAction(editAction, to: target, from: self)
    window?.close()
  }

  @IBAction public func selectNextTab(_ sender: Any?) {
    scopeBar.selectNextButton(sender)
  }

  @IBAction public func selectPreviousTab(_ sender: Any?) {
    scopeBar.selectPreviousButton(sender)
  }
}

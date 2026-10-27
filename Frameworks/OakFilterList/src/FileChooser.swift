import AppKit

/// One row of Open Quickly: a document, where it sits under the project, and how well it matches the filter.
///
/// The items are ranked on a concurrent queue, each by its own iteration and none by two, which is what the
/// unchecked conformance states. The row's cell binds to the icon, the name, the folder and the close state by key,
/// and the first and last follow the document through the key paths declared below.
final class FileChooserItem: NSObject, @unchecked Sendable {
  /// The document, untyped since its class is declared with C++ types the Swift cannot see. Dynamic, so that
  /// the cell's bindings follow it to the document's own icon and open state.
  @objc dynamic let document: AnyObject
  let path: String
  /// The document's directory as seen from the project, "." at the top, and empty for an untitled document.
  let directory: String
  /// The file's name, or the untitled document's display name.
  let file: String
  private let lruRank: Int
  private let isCurrent: Bool

  private(set) var matched = false
  private var rank = 0.0
  private var coverDirectory: [NSRange] = []
  private var coverFile: [NSRange] = []
  private var cachedName: NSAttributedString?
  private var cachedFolder: NSAttributedString?

  init(document: AnyObject, base: String, isCurrent: Bool) {
    self.document = document
    let documentPath = TMDocuments.path(ofDocument: document)
    path = documentPath ?? ""
    if let documentPath {
      let relative = TMPaths.relativePath(TMPaths.parent(ofPath: documentPath), toBase: base)
      directory = relative.isEmpty ? "." : relative
      file = (documentPath as NSString).lastPathComponent
    } else {
      directory = ""
      file = TMDocuments.displayName(ofDocument: document)
    }
    lruRank = TMDocuments.lruRank(forDocument: document)
    self.isCurrent = isCurrent
  }

  @objc static func keyPathsForValuesAffectingIcon() -> Set<String> {
    ["document.icon"]
  }

  @objc var icon: NSImage? {
    guard let image = TMDocuments.icon(ofDocument: document)?.copy() as? NSImage else { return nil }
    image.size = NSSize(width: 32, height: 32)
    return image
  }

  @objc static func keyPathsForValuesAffectingCloseDisabled() -> Set<String> {
    ["document.open", "document.path"]
  }

  /// The close button is for an open document with a file. The cell binds to this as "closeDisabled".
  @objc var isCloseDisabled: Bool {
    !TMDocuments.isDocumentOpen(document) || TMDocuments.path(ofDocument: document) == nil
  }

  @objc var name: NSAttributedString {
    if let cachedName { return cachedName }
    let name = markedUpString(file, byteRanges: coverFile, lineBreakMode: .byTruncatingTail)
    cachedName = name
    return name
  }

  @objc var folder: NSAttributedString {
    if let cachedFolder { return cachedFolder }
    let folder = markedUpString(directory, byteRanges: coverDirectory, lineBreakMode: .byTruncatingHead)
    cachedFolder = folder
    return folder
  }

  /// Whether the match reached into the directory, which a remembered pick does not record.
  var isDirectoryMatched: Bool {
    !coverDirectory.isEmpty
  }

  private func reset() {
    matched = false
    cachedName = nil
    cachedFolder = nil
    rank = 0
    coverDirectory = []
    coverFile = []
  }

  /// How well the item matches the filter: by the file's name first, where a remembered pick for this filter
  /// outranks any match, and by the directory and name together when the name alone does not match. With no
  /// filter everything matches, the current document ahead of the rest.
  func updateRank(filter: String, bindings: [String]) {
    reset()

    var rank = isCurrent ? 0.1 : 3.0
    if !filter.isEmpty {
      if let match = TMRanker.rankFilter(filter, candidate: file) {
        coverFile = match.byteRanges.map(\.rangeValue)
        rank = match.score + 1
        if let index = bindings.firstIndex(of: path) {
          rank = 2 + Double(bindings.count - index) / Double(bindings.count)
        }
      } else if let match = TMRanker.rankFilter(filter, candidate: directory + "/" + file) {
        rank = match.score
        let directoryLength = directory.utf8.count
        for range in match.byteRanges.map(\.rangeValue) {
          let end = NSMaxRange(range)
          if range.location < directoryLength {
            coverDirectory.append(NSRange(location: range.location, length: min(end, directoryLength) - range.location))
          }
          if directoryLength + 1 < end {
            let start = max(range.location, directoryLength + 1) - directoryLength - 1
            coverFile.append(NSRange(location: start, length: end - directoryLength - 1 - start))
          }
        }
      } else {
        rank = 0
      }
    }

    if rank != 0 {
      matched = true
      self.rank = 3 - rank
    }
  }

  func updateRank(glob: TMGlob) {
    reset()
    matched = glob.matches(path)
  }

  /// Better rank first, then the more recently used, then by name.
  func ranksBefore(_ other: FileChooserItem) -> Bool {
    if rank != other.rank {
      return rank < other.rank
    }
    if lruRank != other.lruRank {
      return lruRank > other.lruRank
    }
    return namesBefore(other)
  }

  func namesBefore(_ other: FileChooserItem) -> Bool {
    file.localizedCompare(other.file) == .orderedAscending
  }
}

/// The documents a search has found and not yet shown, shared between the searching thread and the main one.
private final class SearchResults: @unchecked Sendable {
  private let lock = NSLock()
  private var token = 0
  private var documents: [AnyObject] = []

  func withLock<Result>(_ body: (_ token: inout Int, _ documents: inout [AnyObject]) -> Result) -> Result {
    lock.withLock { body(&token, &documents) }
  }
}

/// Open Quickly: every file under the project, the open documents, or the ones with uncommitted changes, filtered as the
/// person types. The filter can be a glob, and can carry a line or a symbol to go to after the file name.
@objc(FileChooser)
@MainActor
public final class FileChooser: Chooser, NSMenuItemValidation {
  @objc public static let sharedInstance = FileChooser()

  enum Source: Int {
    case all = 0
    case openDocuments = 1
    case uncommittedChanges = 2
  }

  private static let sourceIndexKey = "fileChooserSourceIndex"
  private static let bindingsName = "OakFileChooserBindings"

  /// What the person typed, taken apart: a glob when there is a star in it, otherwise a filter, and after either a
  /// line or range after a colon, or a symbol after an at sign.
  struct ParsedFilter: Equatable {
    var glob: String?
    var filter: String?
    var selection: String?
    var symbol: String?

    /// The part that decides which files are listed.
    var listing: String {
      glob ?? filter ?? ""
    }

    /// A glob with a star, or else a filter, then an optional line or range after a colon, or a symbol after an at sign.
    private static let pattern = try? NSRegularExpression(pattern: #"\A(?:(.*?\*.*?)|(.*?))(?::([\d+:\-x]*)|@(.*))?\z"#, options: .anchorsMatchLines)

    static func parse(_ string: String?) -> ParsedFilter {
      guard let string = string?.decomposedStringWithCanonicalMapping, let pattern else { return ParsedFilter() }
      let whole = NSRange(string.startIndex..., in: string)
      guard let match = pattern.firstMatch(in: string, options: .anchored, range: whole) else { return ParsedFilter() }
      func group(_ index: Int) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: string) else { return nil }
        return String(string[swiftRange])
      }
      var parsed = ParsedFilter(glob: group(1), filter: group(2), selection: group(3), symbol: group(4))
      parsed.filter = parsed.filter.map(TMRanker.normalizeFilter)
      return parsed
    }
  }

  private let scopeBar = OakScopeBarViewController()
  private let progressIndicator = NSProgressIndicator(frame: .zero)
  private var records: [FileChooserItem] = []
  private var parsedFilter = ParsedFilter()
  private var sourceControlStatus: TMSourceControlStatus?

  private var searching = false
  private var searchPath: String?
  private let searchResults = SearchResults()
  private var pollTimer: Timer?
  private var pollInterval = 0.02

  /// The project directory the search runs under and paths are shown relative to.
  @objc public var path: String? {
    didSet {
      guard path != oldValue else { return }
      sourceControlStatus = nil
      switch Source(rawValue: sourceIndex) {
      case .all: startSearch(path)
      case .uncommittedChanges: reloadSourceControlStatus()
      default: break
      }
      updateWindowTitle()
    }
  }

  /// The document the person is in, which ranks first when there is no filter.
  @objc public var currentDocument: UUID? {
    didSet {
      guard currentDocument != oldValue else { return }
      reload()
    }
  }

  /// Which list is shown, as the scope bar's index. The scope bar binds to it, so it is dynamic.
  @objc public dynamic var sourceIndex: Int = 0 {
    didSet {
      guard sourceIndex != oldValue else { return }
      updateWindowTitle()
      reload()
      if sourceIndex == 0 {
        UserDefaults.standard.removeObject(forKey: Self.sourceIndexKey)
      } else {
        UserDefaults.standard.set(sourceIndex, forKey: Self.sourceIndexKey)
      }
    }
  }

  public convenience init() {
    self.init(window: nil)
    tableView.allowsMultipleSelection = true
    tableView.rowHeight = 38

    scopeBar.labels = ["All", "Open Documents", "Uncommitted Documents"]

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

    progressIndicator.style = .spinning
    progressIndicator.controlSize = .small
    progressIndicator.isDisplayedWhenStopped = false

    let footerViews: [String: NSView] = [
      "dividerView": ChooserConstruction.separator(),
      "statusTextField": statusTextField,
      "itemCountTextField": itemCountTextField,
      "progressIndicator": progressIndicator,
    ]
    ChooserConstruction.addAutoLayoutViews(Array(footerViews.values), to: footerView)
    footerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[dividerView]|", metrics: nil, views: footerViews))
    let footerRow = "H:|-(24)-[statusTextField]-[itemCountTextField]-(4)-[progressIndicator]-(4)-|"
    footerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: footerRow, options: .alignAllCenterY, metrics: nil, views: footerViews))
    footerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[dividerView(==1)]-(4)-[statusTextField]-(5)-|", metrics: nil, views: footerViews))

    updateScrollViewInsets()

    ChooserConstruction.setUpKeyViewLoop([searchField, scopeBar.view])
    window?.initialFirstResponder = searchField

    sourceIndex = UserDefaults.standard.integer(forKey: Self.sourceIndexKey)
    updateWindowTitle()
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

  public override func windowWillClose(_ notification: Notification) {
    stopSearch()
    sourceControlStatus = nil
    records = []
    items = []
  }

  private func updateWindowTitle() {
    let title: String?
    switch Source(rawValue: sourceIndex) {
    case .all: title = (path as NSString?)?.abbreviatingWithTildeInPath
    case .openDocuments: title = "Open Documents"
    case .uncommittedChanges: title = "Uncommitted Documents"
    case nil: title = nil
    }
    window?.title = title ?? "Open Quickly"
  }

  // MARK: Records

  private func addRecords(for documents: [Any]) {
    let base = path ?? ""
    let firstDirty = records.count
    for document in documents.map({ $0 as AnyObject }) {
      let isCurrent = currentDocument.map { TMDocuments.identifier(ofDocument: document) == $0.uuidString } ?? false
      records.append(FileChooserItem(document: document, base: base, isCurrent: isCurrent))
    }
    updateRecords(from: firstDirty)
  }

  /// Ranks the records from the index on, concurrently since a project can have thousands, and shows the ones that
  /// match. A glob lists by name alone, the filter by rank.
  private func updateRecords(from first: Int) {
    let records = self.records
    let count = records.count - first
    let byRank: Bool

    if let globString = parsedFilter.glob, !globString.isEmpty {
      let glob = TMGlob(pattern: globString)
      DispatchQueue.concurrentPerform(iterations: count) { index in
        records[first + index].updateRank(glob: glob)
      }
      byRank = false
    } else {
      let filter = parsedFilter.filter ?? ""
      let bindings = OakAbbreviations.abbreviations(forName: Self.bindingsName).strings(forAbbreviation: filter)
      DispatchQueue.concurrentPerform(iterations: count) { index in
        records[first + index].updateRank(filter: filter, bindings: bindings)
      }
      byRank = true
    }

    let matched = records.filter(\.matched)
    items = byRank ? matched.sorted { $0.ranksBefore($1) } : matched.sorted { $0.namesBefore($1) }
  }

  private func reload() {
    stopSearch()
    sourceControlStatus = nil

    switch Source(rawValue: sourceIndex) {
    case .all:
      startSearch(path)
    case .openDocuments:
      records = []
      addRecords(for: TMDocuments.openDocuments())
    case .uncommittedChanges:
      reloadSourceControlStatus()
    case nil:
      break
    }
  }

  private func reloadSourceControlStatus() {
    if sourceControlStatus == nil, let path, let status = TMSourceControlStatus(forPath: path) {
      status.updateHandler = { [weak self] in
        guard let self, Source(rawValue: sourceIndex) == .uncommittedChanges else { return }
        reloadSourceControlStatus()
      }
      sourceControlStatus = status
    }

    records = []
    if let sourceControlStatus {
      addRecords(for: sourceControlStatus.uncommittedPaths.map { TMDocuments.document(withPath: $0) })
    }
  }

  // MARK: Filtering

  /// The filter is taken apart first, and only a change to the part that lists files reaches the base, which
  /// rebuilds the list. A change to the line or symbol after it does not.
  public override func updateFilterString(_ string: String?) {
    let oldListing = parsedFilter.listing
    parsedFilter = ParsedFilter.parse(string)
    if oldListing != parsedFilter.listing {
      super.updateFilterString(string)
    }
  }

  public override func updateItems(_ sender: Any?) {
    updateRecords(from: 0)
  }

  public override func updateStatusText(_ sender: Any?) {
    if searching {
      let relative = TMPaths.relativePath(searchPath ?? "", toBase: path)
      statusTextField.cell?.lineBreakMode = .byTruncatingMiddle
      statusTextField.stringValue = "Searching “\(relative)”…"
    } else if tableView.selectedRow == -1 {
      statusTextField.stringValue = ""
    } else if let record = items[tableView.selectedRow] as? FileChooserItem {
      var shown: String
      if let documentPath = TMDocuments.path(ofDocument: record.document) {
        if let path, documentPath.hasPrefix(path) {
          shown = TMPaths.relativePath(documentPath, toBase: path)
        } else {
          shown = (documentPath as NSString).abbreviatingWithTildeInPath
        }
      } else {
        shown = TMDocuments.displayName(ofDocument: record.document)
      }
      statusTextField.cell?.lineBreakMode = .byTruncatingHead
      statusTextField.stringValue = shown
    }
  }

  /// What the caller opens: a path, or an identifier for an untitled document, with the line or range typed after
  /// the file name when there was one.
  public override var selectedItems: [Any] {
    tableView.selectedRowIndexes.compactMap { row -> [String: String]? in
      guard let record = items[row] as? FileChooserItem else { return nil }
      var item: [String: String] = [:]
      if let selection = parsedFilter.selection, !selection.isEmpty {
        item["selectionString"] = selection
      }
      if let documentPath = TMDocuments.path(ofDocument: record.document) {
        item["path"] = documentPath
      } else {
        item["identifier"] = TMDocuments.identifier(ofDocument: record.document)
      }
      return item
    }
  }

  // MARK: Rows

  /// The row view: icon, name, folder and a close button, the last hidden unless the document is open with a file.
  public override func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let tableColumn else { return nil }
    let cell: NSTableCellView
    if let existing = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTableCellView {
      cell = existing
    } else {
      let closeButton = ChooserConstruction.closeButton()
      closeButton.target = self
      closeButton.action = #selector(takeItemToClose(from:))

      cell = FileTableCellView(closeButton: closeButton)
      cell.identifier = tableColumn.identifier
      closeButton.bind(.hidden, to: cell, withKeyPath: "objectValue.closeDisabled", options: nil)
    }
    cell.objectValue = items[row]
    return cell
  }

  // MARK: Actions

  public override func accept(_ sender: Any?) {
    if let filter = parsedFilter.filter, !filter.isEmpty {
      for row in tableView.selectedRowIndexes {
        guard let item = items[row] as? FileChooserItem, !item.isDirectoryMatched, let documentPath = TMDocuments.path(ofDocument: item.document) else { continue }
        OakAbbreviations.abbreviations(forName: Self.bindingsName).learn(abbreviation: filter, forString: documentPath)
      }
    }
    super.accept(sender)
  }

  /// Closes the row's document through whoever answers for closing files, which is the file browser's window.
  @objc private func takeItemToClose(from sender: NSButton) {
    let row = tableView.row(for: sender)
    guard row != -1, let item = items[row] as? FileChooserItem, let documentPath = TMDocuments.path(ofDocument: item.document) else { return }
    let selector = Selector(("fileBrowser:closeURL:"))
    if let target = NSApp.target(forAction: selector) as? NSObject {
      target.perform(selector, with: nil, with: URL(fileURLWithPath: documentPath))
    }
  }

  @IBAction public func goToParentFolder(_ sender: Any?) {
    path = (path as NSString?)?.deletingLastPathComponent
  }

  public func validateMenuItem(_ item: NSMenuItem) -> Bool {
    if item.action == #selector(goToParentFolder(_:)) {
      guard let path, Source(rawValue: sourceIndex) == .all else { return false }
      return path != TMPaths.parent(ofPath: path)
    }
    return true
  }
}

// MARK: Searching

extension FileChooser {
  /// Walks the directory on a background queue, gathering documents under the lock for the main queue to show in
  /// batches. The main queue waits for the first document that is not already open, or for the walk to end, so that
  /// the first batch is on screen when the window is, and then polls at a widening interval. A token tells a stale
  /// walk's results from the current one.
  private func startSearch(_ path: String?) {
    if searching {
      stopSearch()
    }

    items = []
    records = []

    guard let path else { return }

    let token = searchResults.withLock { token, documents in
      documents.removeAll()
      return token
    }
    searching = true

    let semaphore = DispatchSemaphore(value: 0)
    let results = searchResults

    DispatchQueue.global(qos: .default).async { [weak self] in
      var didSignal = false

      TMDocuments.enumerateDocuments(atPath: path) { document, stop in
        results.withLock { current, documents in
          if !didSignal, !TMDocuments.isDocumentOpen(document) {
            semaphore.signal()
            didSignal = true
          }
          if token == current {
            documents.append(document as AnyObject)
          } else {
            stop.pointee = true
          }
        }
      }

      if !didSignal {
        semaphore.signal()
      }

      DispatchQueue.main.async {
        MainActor.assumeIsolated {
          guard let self, token == self.searchResults.withLock({ current, _ in current }) else { return }
          self.searching = false
          self.handleSearchResults()
        }
      }
    }

    semaphore.wait()
    handleSearchResults()

    pollInterval = 0.02
    pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: false) { [weak self] _ in
      MainActor.assumeIsolated { self?.handleSearchResults() }
    }
    progressIndicator.perform(#selector(NSProgressIndicator.startAnimation(_:)), with: self, afterDelay: 0.2)
  }

  private func handleSearchResults() {
    let found = searchResults.withLock { _, documents in
      let found = documents
      documents.removeAll()
      return found
    }
    if !found.isEmpty || !searching {
      searchPath = searching ? found.last.flatMap { TMDocuments.path(ofDocument: $0) }.map { ($0 as NSString).deletingLastPathComponent } : nil
    }
    addRecords(for: found)

    if searching {
      pollInterval = min(pollInterval * 2, 0.32)
      pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: false) { [weak self] _ in
        MainActor.assumeIsolated { self?.handleSearchResults() }
      }
    } else {
      stopSearch()
      updateStatusText(self)
    }
  }

  private func stopSearch() {
    if searching {
      searching = false
      searchResults.withLock { token, _ in token += 1 }
    }

    NSObject.cancelPreviousPerformRequests(withTarget: progressIndicator, selector: #selector(NSProgressIndicator.startAnimation(_:)), object: self)
    progressIndicator.stopAnimation(self)
    pollTimer?.invalidate()
    pollTimer = nil
  }

}

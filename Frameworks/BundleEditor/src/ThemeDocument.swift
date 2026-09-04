import BundleSchema
import Foundation
import Observation

/// The part of a theme the editor edits: the settings list, the gutter's
/// colors and the color space. The theme's name, author and comment belong
/// to the properties panel beside it.
@Observable
@MainActor
final class ThemeDocument {
  var entries: [ThemeEntry] = []
  let gutter: SchemaValues
  var colorSpaceName: String?

  /// Keys the editor does not know, written back as they came.
  private var extra: [String: Any] = [:]

  /// The theme's other keys, from the properties panel. Not written back
  /// from here.
  var context: [String: Any] = [:]

  init() {
    gutter = SchemaValues()
  }

  init(dictionary: [String: Any]) {
    var remaining = dictionary
    entries = (remaining.removeValue(forKey: "settings") as? [Any] ?? []).compactMap { ($0 as? [String: Any]).map(ThemeEntry.init(dictionary:)) }
    gutter = SchemaValues(remaining.removeValue(forKey: "gutterSettings") as? [String: Any] ?? [:])
    colorSpaceName = remaining.removeValue(forKey: "colorSpaceName") as? String
    extra = remaining
  }

  var dictionary: [String: Any] {
    var result = extra
    result["settings"] = entries.map(\.dictionary)
    if !gutter.dictionary.isEmpty { result["gutterSettings"] = gutter.dictionary }
    if let colorSpaceName { result["colorSpaceName"] = colorSpaceName }
    return result
  }

  /// The whole theme as the theme code wants it.
  var fullDictionary: [String: Any] {
    context.merging(dictionary) { _, edited in edited }
  }

  /// The entry without a scope, which sets the page, made on demand so the
  /// form always has one to show.
  var page: ThemeEntry {
    if let page = entries.first(where: \.isPage) {
      return page
    }
    let page = ThemeEntry()
    entries.insert(page, at: 0)
    return page
  }

  /// The scoped entries, in order.
  var scopedEntries: [ThemeEntry] {
    entries.filter { !$0.isPage }
  }

  func entry(with id: ThemeEntry.ID) -> ThemeEntry? {
    entries.first { $0.id == id }
  }

  var issues: [SchemaIssue] {
    ThemeValidator().issues(in: dictionary)
  }

  // MARK: - Adding, removing and moving

  /// Adds a scoped entry after another, or at the end.
  func addEntry(after id: ThemeEntry.ID?) -> ThemeEntry {
    let entry = ThemeEntry(name: "", scope: "", style: [:])
    if let id, let index = entries.firstIndex(where: { $0.id == id }) {
      entries.insert(entry, at: index + 1)
    } else {
      entries.append(entry)
    }
    return entry
  }

  func remove(_ id: ThemeEntry.ID) {
    entries.removeAll { $0.id == id && !$0.isPage }
  }

  func move(_ id: ThemeEntry.ID, by offset: Int) {
    guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
    let target = index + offset
    guard entries.indices.contains(target), !entries[index].isPage, !entries[target].isPage else { return }
    entries.swapAt(index, target)
  }

  func canMove(_ id: ThemeEntry.ID, by offset: Int) -> Bool {
    guard let index = entries.firstIndex(where: { $0.id == id }) else { return false }
    let target = index + offset
    return entries.indices.contains(target) && !entries[index].isPage && !entries[target].isPage
  }
}

import AppKit

/// Which field of an item the typed filter is matched against.
enum BundleItemField: Int {
  case title = 0
  case keyEquivalent = 1
  case tabTrigger = 2
  case semanticClass = 3
  case scopeSelector = 4
}

/// Where the rows come from, as a set: the three tabs each pick a few.
struct BundleItemSearchSources: OptionSet {
  let rawValue: UInt
  static let actions = BundleItemSearchSources(rawValue: 1 << 0)
  static let settings = BundleItemSearchSources(rawValue: 1 << 1)
  static let grammars = BundleItemSearchSources(rawValue: 1 << 2)
  static let themes = BundleItemSearchSources(rawValue: 1 << 3)
  static let dragCommands = BundleItemSearchSources(rawValue: 1 << 4)
  static let menuItems = BundleItemSearchSources(rawValue: 1 << 5)
  static let keyBindings = BundleItemSearchSources(rawValue: 1 << 6)

  /// The sources the bundle index answers for, as the face's options.
  var bundleItemSources: TMBundleItemSources {
    var sources: TMBundleItemSources = []
    if contains(.actions) { sources.insert(.actions) }
    if contains(.settings) { sources.insert(.settings) }
    if contains(.grammars) { sources.insert(.grammars) }
    if contains(.themes) { sources.insert(.themes) }
    if contains(.dragCommands) { sources.insert(.dragCommands) }
    return sources
  }
}

/// One row of Select Bundle Item: a bundle item, one setting, a menu item or a key binding, and how it matches.
///
/// The rows rank on a concurrent queue, each by its own iteration and none by two, which the unchecked conformance
/// states. The caller reads the uuid, the file and the line by key when a row is picked, so those are exposed.
final class BundleItemChooserItem: NSObject, @unchecked Sendable {
  var itemName = ""
  var location = ""
  var icon: NSImage?
  @objc var uuid: String?
  /// A settings file or a key bindings file.
  @objc var file: String?
  /// The line in the settings file.
  @objc var line: String?
  var menuItem: NSMenuItem?
  var action: Selector?
  /// A setting's value, shown after its name.
  var value: String?
  var keyEquivalent: String?
  var tabTrigger: String?
  var scopeSelector: String?
  var semanticClass: String?
  /// Whether something earlier overrides this setting or key, drawn struck through.
  var eclipsed = false
  /// "Command", "Snippet" and so on for a bundle item, nil for the rest.
  var kindName: String?

  private(set) var matched = false
  private(set) var rank = 0.0
  private(set) var name: NSAttributedString?
  private(set) var path: NSAttributedString?

  /// What a remembered pick is recorded under: the bundle item's uuid, the key binding's selector, or the menu item's.
  var identifier: String? {
    uuid ?? action.map { NSStringFromSelector($0) } ?? menuItem.flatMap(Self.menuItemIdentifier)
  }

  static func menuItemIdentifier(_ menuItem: NSMenuItem) -> String? {
    guard let action = menuItem.action else { return nil }
    let name = NSStringFromSelector(action)
    return menuItem.tag != 0 ? name + String(menuItem.tag) : name
  }

  private func reset() {
    matched = false
    rank = 0
    name = nil
    path = nil
  }

  /// A substring match with the matched bytes, case ignored, the way the settings and other tabs search.
  private static func substringCover(of needle: String, in haystack: String) -> NSRange? {
    guard let range = haystack.range(of: needle, options: .caseInsensitive) else { return nil }
    let start = haystack[..<range.lowerBound].utf8.count
    let end = haystack[..<range.upperBound].utf8.count
    return NSRange(location: start, length: end - start)
  }

  /// How well the row matches the filter in the field being searched. For the title, actions rank by the ranker and
  /// everything else by substring, a name match ahead of one through the location. The other fields match whole or
  /// contained. A remembered pick for this filter comes before any match, the most recent foremost.
  func updateRank(filter: String, field: BundleItemField, sources: BundleItemSearchSources, bindings: [String], defaultRank: Double) {
    reset()

    var rank = defaultRank
    var coverPath: [NSRange] = []
    var coverName: [NSRange] = []
    let name = itemName
    let path = location

    if !filter.isEmpty {
      func contains(_ haystack: String?, _ needle: String) -> Bool {
        haystack?.range(of: needle) != nil
      }

      switch field {
      case .title:
        var cover: [NSRange] = []
        if !sources.isDisjoint(with: [.actions, .menuItems, .keyBindings]) {
          if let match = TMRanker.rankFilter(filter, candidate: name) {
            rank = match.score + 1
            cover = match.byteRanges.map(\.rangeValue)
          } else if let match = TMRanker.rankFilter(filter, candidate: path + " " + name) {
            rank = match.score
            cover = match.byteRanges.map(\.rangeValue)
          } else {
            rank = 0
          }
        } else {
          if let range = Self.substringCover(of: filter, in: name) {
            cover = [range]
            rank += 1
          } else if let range = Self.substringCover(of: filter, in: path + " " + name) {
            cover = [range]
          } else {
            rank = 0
          }
        }

        let pathLength = path.utf8.count
        for range in cover {
          let end = NSMaxRange(range)
          if rank > 1 {
            coverName.append(range)
          } else if range.location < pathLength {
            coverPath.append(NSRange(location: range.location, length: min(end, pathLength) - range.location))
          } else if pathLength + 1 < end {
            let start = max(range.location, pathLength + 1) - pathLength - 1
            coverName.append(NSRange(location: start, length: end - pathLength - 1 - start))
          }
        }
      case .keyEquivalent:
        rank = keyEquivalent == filter ? rank : 0
      case .tabTrigger:
        rank = contains(tabTrigger, filter) ? rank : 0
      case .semanticClass:
        rank = contains(semanticClass, filter) ? rank : 0
      case .scopeSelector:
        rank = contains(scopeSelector, filter) ? rank : 0
      }
    }

    matched = rank > 0
    guard matched else { return }

    if field == .title, let identifier, let index = bindings.firstIndex(of: identifier) {
      rank = 2 + Double(bindings.count - index) / Double(bindings.count)
    }

    var shownName = name
    if let value {
      shownName += " = " + value
    }

    let markedUpName = markedUpString(shownName, byteRanges: coverName, lineBreakMode: .byTruncatingTail)
    if eclipsed {
      markedUpName.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: markedUpName.length))
    }
    self.name = markedUpName
    self.path = markedUpString(path, byteRanges: coverPath, lineBreakMode: .byTruncatingHead)
    self.rank = 3 - rank
  }

  /// Better rank first, then by name, then by location.
  func sortsBefore(_ other: BundleItemChooserItem) -> Bool {
    if rank != other.rank {
      return rank < other.rank
    }
    let byName = itemName.localizedCompare(other.itemName)
    if byName != .orderedSame {
      return byName == .orderedAscending
    }
    return location.localizedCompare(other.location) == .orderedAscending
  }
}

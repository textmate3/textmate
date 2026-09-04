import Foundation
import Observation

/// One entry of a theme's settings list: a name, the scope selector it
/// styles, and the style itself, edited by key. The first entry of a theme
/// has no scope and sets the page.
@Observable
@MainActor
final class ThemeEntry: Identifiable {
  let id = UUID()
  var name: String?
  var scope: String?
  var comment: String?
  let style: SchemaValues

  /// Keys the schema does not know, written back as they came.
  private var extra: [String: Any] = [:]

  init(name: String? = nil, scope: String? = nil, style: [String: Any] = [:]) {
    self.name = name
    self.scope = scope
    self.style = SchemaValues(style)
  }

  init(dictionary: [String: Any]) {
    var remaining = dictionary
    name = remaining.removeValue(forKey: "name") as? String
    scope = remaining.removeValue(forKey: "scope") as? String
    comment = remaining.removeValue(forKey: "comment") as? String
    style = SchemaValues(remaining.removeValue(forKey: "settings") as? [String: Any] ?? [:])
    extra = remaining
  }

  var dictionary: [String: Any] {
    var result = extra
    if let name { result["name"] = name }
    if let scope { result["scope"] = scope }
    if let comment { result["comment"] = comment }
    result["settings"] = style.dictionary
    return result
  }

  /// The page entry is the one without a scope.
  var isPage: Bool { scope == nil }

  var title: String {
    if let name, !name.isEmpty { return name }
    if let scope, !scope.isEmpty { return scope }
    return isPage ? "Page" : "entry"
  }
}

import Foundation
import Observation

/// One entry of `shellVariables`: a name, a value, and whether it is left
/// out. Keys the form does not show are kept and written back as they came.
@Observable
@MainActor
final class ShellVariable: Identifiable {
  let id = UUID()
  var name: String
  var value: String
  var enabled: Bool
  private var extra: [String: Any]

  init(dictionary: [String: Any] = [:]) {
    name = dictionary["name"] as? String ?? ""
    value = dictionary["value"] as? String ?? ""
    let disabled = dictionary["disabled"]
    enabled = !((disabled as? Bool) ?? (disabled as? NSNumber)?.boolValue ?? false)
    extra = dictionary.filter { !["name", "value", "disabled"].contains($0.key) }
  }

  var dictionary: [String: Any] {
    var result = extra
    result["name"] = name
    result["value"] = value
    if !enabled {
      result["disabled"] = true
    }
    return result
  }
}

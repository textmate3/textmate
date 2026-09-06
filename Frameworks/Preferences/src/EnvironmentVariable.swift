import Foundation

/// One row of the Variables pane: a variable the application hands every
/// bundle command, and whether it is handed over at all. Stored in defaults as
/// a dictionary with these three keys, which is what the settings framework
/// reads back.
struct EnvironmentVariable: Identifiable, Equatable {
  let id = UUID()
  var isEnabled: Bool
  var name: String
  var value: String

  init(isEnabled: Bool = true, name: String, value: String) {
    self.isEnabled = isEnabled
    self.name = name
    self.value = value
  }

  init?(dictionary: [String: Any]) {
    guard let name = dictionary["name"] as? String else { return nil }
    self.init(
      isEnabled: dictionary["enabled"] as? Bool ?? false,
      name: name,
      value: dictionary["value"] as? String ?? ""
    )
  }

  var dictionary: [String: Any] {
    ["enabled": isEnabled, "name": name, "value": value]
  }
}

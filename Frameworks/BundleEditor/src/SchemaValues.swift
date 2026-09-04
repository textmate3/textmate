import Foundation
import Observation

/// A dictionary a form edits by key. Values are whatever the property list
/// held, read and written through typed accessors, so a form built from a
/// schema's key table needs no named properties. Removing a key is setting
/// it to nil. Keys the form does not show are kept and written back as they
/// came.
@Observable
@MainActor
final class SchemaValues {
  private(set) var dictionary: [String: Any]

  init(_ dictionary: [String: Any] = [:]) {
    self.dictionary = dictionary
  }

  subscript(key: String) -> Any? {
    get { dictionary[key] }
    set {
      if let newValue {
        dictionary[key] = newValue
      } else {
        dictionary.removeValue(forKey: key)
      }
    }
  }

  func string(_ key: String) -> String? {
    dictionary[key] as? String
  }

  /// Sets a text value, removing the key when the text is empty.
  func setString(_ text: String, for key: String) {
    self[key] = text.isEmpty ? nil : text
  }

  func flag(_ key: String) -> Bool? {
    if let flag = dictionary[key] as? Bool { return flag }
    if let number = dictionary[key] as? NSNumber { return number.boolValue }
    return nil
  }

  /// Sets a flag, removing the key when it is off.
  func setFlag(_ flag: Bool, for key: String) {
    self[key] = flag ? true : nil
  }
}

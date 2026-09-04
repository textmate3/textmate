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

  /// A flag as property lists in the wild write one: a boolean, a number,
  /// or the strings 0, 1, true and false.
  func flag(_ key: String) -> Bool? {
    if let flag = dictionary[key] as? Bool { return flag }
    if let number = dictionary[key] as? NSNumber { return number.boolValue }
    if let text = dictionary[key] as? String { return ["1", "true"].contains(text) ? true : ["0", "false"].contains(text) ? false : nil }
    return nil
  }

  /// Sets a flag, removing the key when it is off.
  func setFlag(_ flag: Bool, for key: String) {
    self[key] = flag ? true : nil
  }

  func strings(_ key: String) -> [String] {
    (dictionary[key] as? [Any])?.compactMap { $0 as? String } ?? []
  }

  /// Sets a list of strings, removing the key when the list is empty.
  func setStrings(_ strings: [String], for key: String) {
    self[key] = strings.isEmpty ? nil : strings
  }

  /// Two string lists, opener and closer. Lists of any other length are
  /// not pairs and are left out.
  func pairs(_ key: String) -> [[String]] {
    (dictionary[key] as? [Any])?.compactMap { pair in
      guard let pair = pair as? [Any], pair.count == 2, let opener = pair[0] as? String, let closer = pair[1] as? String else { return nil }
      return [opener, closer]
    } ?? []
  }

  /// Sets the pairs, removing the key when there are none.
  func setPairs(_ pairs: [[String]], for key: String) {
    self[key] = pairs.isEmpty ? nil : pairs
  }
}

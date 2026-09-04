import Foundation
import Observation

/// One recorded step of a macro: the selector the text view performed and
/// the argument it was given, which is nothing, text, or a dictionary of
/// a command's options. Keys the form does not show are kept and written
/// back as they came.
@Observable
@MainActor
final class MacroStep: Identifiable {
  let id = UUID()
  var command: String
  var argument: Any?
  private var extra: [String: Any]

  init(dictionary: [String: Any] = [:]) {
    command = dictionary["command"] as? String ?? ""
    argument = dictionary["argument"]
    extra = dictionary.filter { !["command", "argument"].contains($0.key) }
  }

  var dictionary: [String: Any] {
    var result = extra
    result["command"] = command
    if let argument {
      result["argument"] = argument
    }
    return result
  }

  /// The argument when it is text, as typed text is.
  var argumentText: String? {
    get { argument as? String }
    set { argument = newValue.flatMap { $0.isEmpty ? nil : $0 } }
  }

  /// The argument when it is a dictionary, as a command's options are.
  var argumentOptions: [String: Any]? {
    argument as? [String: Any]
  }

  func setOption(_ text: String, for key: String) {
    var options = argumentOptions ?? [:]
    options[key] = text
    argument = options
  }

  /// The selector without its colon, followed by a glimpse of the argument.
  var title: String {
    let name = command.hasSuffix(":") ? String(command.dropLast()) : command
    if let text = argumentText {
      return "\(name) \(text.debugDescription)"
    }
    if let options = argumentOptions, let glimpse = options["findString"] as? String ?? options["name"] as? String ?? options["command"] as? String {
      return "\(name) \(glimpse.debugDescription)"
    }
    return name
  }
}

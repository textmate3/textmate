import AppKit

/// What a person picked the last time they typed a given abbreviation.
///
/// Every chooser keeps one of these under its own name, so typing `fcm` in Go
/// to File offers the file that was chosen for `fcm` before, ahead of whatever
/// the ranker would have put first.
@objc(OakAbbreviations)
public final class OakAbbreviations: NSObject {
  /// A remembered pick. The keys are what the old dictionaries used, because
  /// the list is in user defaults and people have one already.
  private struct Binding: Equatable {
    static let abbreviationKey = "short"
    static let expansionKey = "long"

    let abbreviation: String
    let expansion: String

    init(abbreviation: String, expansion: String) {
      self.abbreviation = abbreviation
      self.expansion = expansion
    }

    init?(dictionary: [String: String]) {
      guard let abbreviation = dictionary[Self.abbreviationKey],
            let expansion = dictionary[Self.expansionKey] else { return nil }
      self.init(abbreviation: abbreviation, expansion: expansion)
    }

    var dictionary: [String: String] {
      [Self.abbreviationKey: abbreviation, Self.expansionKey: expansion]
    }
  }

  /// How many picks are kept. Beyond this the oldest are forgotten, since the
  /// list is searched in full on every keystroke.
  public static let limit = 50

  private let name: String
  private let defaults: UserDefaults
  private var bindings: [Binding]

  @objc(abbreviationsForName:)
  public static func abbreviations(forName name: String) -> OakAbbreviations {
    shared.withLock { instances in
      if let existing = instances[name] { return existing }
      let created = OakAbbreviations(name: name, defaults: .standard)
      instances[name] = created
      return created
    }
  }

  private static let shared = Mutex<[String: OakAbbreviations]>([:])

  init(name: String, defaults: UserDefaults) {
    self.name = name
    self.defaults = defaults
    self.bindings = (defaults.array(forKey: name) as? [[String: String]] ?? []).compactMap(Binding.init(dictionary:))
    super.init()
  }

  /// What was picked for this abbreviation, best first: the exact matches, then
  /// the ones this is a prefix of. An empty abbreviation matches nothing, since
  /// every remembered pick would be a prefix match and the list would be no
  /// help at all.
  @objc(stringsForAbbreviation:)
  public func strings(forAbbreviation abbreviation: String) -> [String] {
    guard !abbreviation.isEmpty else { return [] }

    let exact = bindings.filter { $0.abbreviation == abbreviation }
    let prefix = bindings.filter { $0.abbreviation != abbreviation && $0.abbreviation.hasPrefix(abbreviation) }
    return (exact + prefix).map(\.expansion)
  }

  /// Remembers that this abbreviation meant this. The newest pick goes first,
  /// and repeating one moves it rather than recording it twice.
  @objc(learnAbbreviation:forString:)
  public func learn(abbreviation: String, forString string: String) {
    guard !abbreviation.isEmpty, !string.isEmpty else { return }

    let binding = Binding(abbreviation: abbreviation, expansion: string)
    bindings.removeAll { $0 == binding }
    bindings.insert(binding, at: 0)

    // Trimming and saving here rather than at termination, which is what the
    // class this replaces did. That meant the list grew without limit for as
    // long as the application ran, and that nothing was written at all if it
    // exited any way other than quitting.
    if bindings.count > Self.limit {
      bindings.removeLast(bindings.count - Self.limit)
    }
    save()
  }

  /// What is remembered, newest first. For tests and for anything that wants to
  /// show the list.
  public var rememberedStrings: [String] { bindings.map(\.expansion) }

  private func save() {
    defaults.set(bindings.map(\.dictionary), forKey: name)
  }
}

/// The smallest lock that will do, so the shared instances are safe to ask for
/// from anywhere. `OSAllocatedUnfairLock` needs a platform newer than this one
/// targets for the generic form, so this wraps `NSLock`.
private final class Mutex<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Value

  init(_ value: Value) { self.value = value }

  func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
    lock.lock()
    defer { lock.unlock() }
    return body(&value)
  }
}

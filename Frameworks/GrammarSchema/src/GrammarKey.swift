/// One key a grammar or a rule may carry: its name in the property list, the
/// kind of value behind it, and a line for the form to show as help.
public struct GrammarKey: Sendable, Equatable, Identifiable {
  public let name: String
  public let kind: GrammarValueKind
  public let summary: String

  public var id: String { name }

  public init(_ name: String, _ kind: GrammarValueKind, _ summary: String) {
    self.name = name
    self.kind = kind
    self.summary = summary
  }
}

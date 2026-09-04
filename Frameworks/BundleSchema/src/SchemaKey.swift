/// One key a bundle item, or a part of one, may carry: its name in the
/// property list, the kind of value behind it, and a line for a form to show
/// as help.
public struct SchemaKey: Sendable, Equatable, Identifiable {
  public let name: String
  public let kind: SchemaValueKind
  public let summary: String

  public var id: String { name }

  public init(_ name: String, _ kind: SchemaValueKind, _ summary: String) {
    self.name = name
    self.kind = kind
    self.summary = summary
  }
}

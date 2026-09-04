/// Keys that belong together in a form, under one heading.
public struct SchemaGroup: Sendable, Equatable, Identifiable {
  public let name: String
  public let keys: [SchemaKey]

  public var id: String { name }

  public init(_ name: String, _ keys: [SchemaKey]) {
    self.name = name
    self.keys = keys
  }
}

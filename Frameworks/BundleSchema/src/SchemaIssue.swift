/// Something a validator found, with the path to where it found it, written
/// the way a person would point at it: `repository.string.patterns[2]`.
public struct SchemaIssue: Sendable, Equatable, CustomStringConvertible {
  public let path: String
  public let message: String

  public init(path: String, message: String) {
    self.path = path
    self.message = message
  }

  public var description: String { path.isEmpty ? message : "\(path): \(message)" }
}

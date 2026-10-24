import Foundation
import os

/// The change log one installed bundle carries.
/// It is `Changes.json` at the top of the bundle, written by the catalog from the bundle's git history when the archive is built.
/// The commit messages are in it as git has them.
public struct BundleChanges: Decodable, Equatable, Sendable {
  public let name: String
  public let commits: [BundleCommit]

  public init(name: String, commits: [BundleCommit]) {
    self.name = name
    self.commits = commits
  }

  /// The file decoded, with its dates read as the ISO 8601 instants the catalog writes.
  public init(data: Data) throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self = try decoder.decode(BundleChanges.self, from: data)
  }

  /// The file at the URL, or nil when there is none to read.
  /// A bundle that did not come from the catalog carries no change log, and the tab goes on without it.
  /// A file that is there and will not decode is logged, since that is the catalog's mistake and worth seeing.
  public static func read(_ url: URL) -> BundleChanges? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    do {
      return try BundleChanges(data: data)
    } catch {
      Logger(subsystem: "com.textmate3.TextMate", category: "BundleChanges").error("\(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
      return nil
    }
  }
}

/// One commit of a bundle's history: when, by whom, the summary line and the rest of the message.
public struct BundleCommit: Decodable, Equatable, Sendable {
  public let date: Date
  public let author: String
  public let summary: String
  public let body: String

  public init(date: Date, author: String, summary: String, body: String) {
    self.date = date
    self.author = author
    self.summary = summary
    self.body = body
  }
}

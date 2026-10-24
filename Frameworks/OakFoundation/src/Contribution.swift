import Foundation

/// One commit to the application's repository, as the About window's Contributions page shows it.
/// The data is written by `script/update_contributions`, one JSON file per year, and shipped in the application's resources.
/// The message is as git has it. The account is the one GitHub resolved the author to, and may be absent.
public struct Contribution: Decodable, Equatable, Sendable {
  public let hash: String
  public let date: Date
  public let author: ContributionAuthor
  public let summary: String
  public let body: String

  public init(hash: String, date: Date, author: ContributionAuthor, summary: String, body: String) {
    self.hash = hash
    self.date = date
    self.author = author
    self.summary = summary
    self.body = body
  }

  /// The commit on GitHub, in this repository.
  public var commitURL: URL? {
    URL(string: "https://github.com/textmate3/textmate/commit/\(hash)")
  }

  /// The first ten characters of the hash, the way the page shows it.
  public var shortHash: String {
    String(hash.prefix(10))
  }
}

/// Who made a commit: the name git recorded, and the GitHub account GitHub resolved it to, when it could.
public struct ContributionAuthor: Decodable, Equatable, Sendable {
  public let name: String
  public let username: String?
  public let avatarURL: URL?

  public init(name: String, username: String?, avatarURL: URL?) {
    self.name = name
    self.username = username
    self.avatarURL = avatarURL
  }

  /// The author's GitHub profile, when GitHub knew who they were.
  public var profileURL: URL? {
    username.flatMap { URL(string: "https://github.com/\($0)") }
  }

  private enum CodingKeys: String, CodingKey {
    case avatarURL = "avatar_url"
    case name
    case username
  }
}

/// One year's file as written: the year and its commits, newest first.
public struct ContributionYear: Decodable, Equatable, Sendable {
  public let year: Int
  public let commits: [Contribution]

  public init(year: Int, commits: [Contribution]) {
    self.year = year
    self.commits = commits
  }

  /// Every year file in the directory, newest year first.
  /// A directory that cannot be listed or a file that will not decode is thrown, since the page would rather say so than show nothing.
  public static func read(directory: URL) throws -> [ContributionYear] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
    return try files.map { try decoder.decode(ContributionYear.self, from: Data(contentsOf: $0)) }.sorted { $0.year > $1.year }
  }

  /// The commits grouped by the calendar day they were authored, in the order they are in, under the title the page shows for the day, such as "Sep 15, 2026".
  /// The calendar is passed in rather than read from the machine, so a test groups the same way on any machine.
  public func days(calendar: Calendar = .current) -> [ContributionDay] {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = calendar.locale
    formatter.timeZone = calendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate("MMM d yyyy")

    var days: [ContributionDay] = []
    for commit in commits {
      let title = formatter.string(from: commit.date)
      if let last = days.last, last.title == title {
        days[days.count - 1] = ContributionDay(title: title, commits: last.commits + [commit])
      } else {
        days.append(ContributionDay(title: title, commits: [commit]))
      }
    }
    return days
  }
}

/// The commits of one calendar day, under the title the page shows for it.
public struct ContributionDay: Equatable, Sendable {
  public let title: String
  public let commits: [Contribution]

  public init(title: String, commits: [Contribution]) {
    self.title = title
    self.commits = commits
  }
}

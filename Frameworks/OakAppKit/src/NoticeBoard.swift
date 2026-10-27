import Foundation
import Observation

/// One thing the application has to tell the person about something that happened on its own.
/// A notice with a key stands for a condition that can go away, a settings file with a bad header say,
/// and the key is what lets the poster replace it or take it down when the condition changes.
public struct Notice: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let text: String
  public let key: String?

  public init(text: String, key: String? = nil) {
    id = UUID()
    self.text = text
    self.key = key
  }
}

/// What the application has to say about things that happened on their own, for every document window to show.
/// A runtime installed at launch, a fallback to another one, an install that failed: none of these happened because the person did something,
/// so none belongs in an alert, and the log is where they went until now, read by nobody.
/// The board holds them until the person dismisses them, which dismisses them everywhere at once, and the next launch starts empty.
/// The same text posted twice is one notice, so a resolver that runs twice does not say it twice.
@objc(OakNoticeBoard)
@MainActor
@Observable
public final class NoticeBoard: NSObject {
  @objc public static let shared = NoticeBoard()

  /// Posted on the default center when a notice is added or dismissed, with the board as the object.
  @objc public static let didChangeNotification = Notification.Name("OakNoticeBoardDidChange")

  public private(set) var notices: [Notice] = []

  public override init() {
    super.init()
  }

  @objc public var isEmpty: Bool {
    notices.isEmpty
  }

  @objc public func post(_ text: String) {
    guard !notices.contains(where: { $0.text == text }) else { return }
    notices.append(Notice(text: text))
    changed()
  }

  /// Posts a notice under a key. A notice already under that key is replaced in place if its text differs, and left alone if not.
  @objc public func post(_ text: String, key: String) {
    if let index = notices.firstIndex(where: { $0.key == key }) {
      guard notices[index].text != text else { return }
      notices[index] = Notice(text: text, key: key)
    } else {
      notices.append(Notice(text: text, key: key))
    }
    changed()
  }

  public func dismiss(_ notice: Notice) {
    guard notices.contains(notice) else { return }
    notices.removeAll { $0.id == notice.id }
    changed()
  }

  /// Takes down every notice whose key starts with the prefix, which is how a poster clears all it said about one file.
  @objc public func dismissNotices(withKeyPrefix prefix: String) {
    let remaining = notices.filter { !($0.key?.hasPrefix(prefix) ?? false) }
    guard remaining.count != notices.count else { return }
    notices = remaining
    changed()
  }

  private func changed() {
    NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
  }
}

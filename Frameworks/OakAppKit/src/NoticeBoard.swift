import Foundation
import Observation

/// One thing the application has to tell the person about something that happened on its own.
public struct Notice: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let text: String

  public init(text: String) {
    id = UUID()
    self.text = text
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

  public func dismiss(_ notice: Notice) {
    guard notices.contains(notice) else { return }
    notices.removeAll { $0.id == notice.id }
    changed()
  }

  private func changed() {
    NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
  }
}

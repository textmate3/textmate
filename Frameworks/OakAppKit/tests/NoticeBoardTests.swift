import Foundation
import OakAppKit
import Testing

/// The board a document window's strip shows: what posting and dismissing do, and that each change is announced.
@Suite @MainActor struct NoticeBoardTests {
  @Test func startsEmpty() {
    let board = NoticeBoard()
    #expect(board.isEmpty)
    #expect(board.notices.isEmpty)
  }

  @Test func postingAddsANoticeInOrder() {
    let board = NoticeBoard()
    board.post("Installed Ruby 4.0.9 for bundle commands.")
    board.post("Bundle commands run on a Python other than 3.14.9.")
    #expect(!board.isEmpty)
    #expect(board.notices.map(\.text) == ["Installed Ruby 4.0.9 for bundle commands.", "Bundle commands run on a Python other than 3.14.9."])
  }

  @Test func theSameTextTwiceIsOneNotice() {
    let board = NoticeBoard()
    board.post("Installed Ruby 4.0.9 for bundle commands.")
    board.post("Installed Ruby 4.0.9 for bundle commands.")
    #expect(board.notices.count == 1)
  }

  @Test func dismissingRemovesThatNoticeAlone() throws {
    let board = NoticeBoard()
    board.post("First")
    board.post("Second")
    let first = try #require(board.notices.first)
    board.dismiss(first)
    #expect(board.notices.map(\.text) == ["Second"])
    board.dismiss(try #require(board.notices.first))
    #expect(board.isEmpty)
  }

  @Test func dismissingANoticeThatIsNotThereChangesNothing() {
    let board = NoticeBoard()
    board.post("Only")
    board.dismiss(Notice(text: "Only"))
    #expect(board.notices.count == 1)
  }

  @Test func everyChangeIsAnnouncedWithTheBoardAsObject() throws {
    let board = NoticeBoard()
    // The board posts synchronously on the thread that changed it, which is this one, so the count is read after the last post without a race.
    nonisolated(unsafe) var announcements = 0
    let observer = NotificationCenter.default.addObserver(forName: NoticeBoard.didChangeNotification, object: board, queue: nil) { _ in
      announcements += 1
    }
    defer { NotificationCenter.default.removeObserver(observer) }

    board.post("One")
    board.post("One")
    board.dismiss(try #require(board.notices.first))
    board.dismiss(Notice(text: "gone"))
    #expect(announcements == 2)
  }
}

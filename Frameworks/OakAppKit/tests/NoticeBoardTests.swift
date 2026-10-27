import Foundation
import OakAppKit
import Testing

/// The board a document window's banner shows: what posting and dismissing do, and that each change is announced.
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

  @Test func aKeyedNoticeIsReplacedInPlaceWhenItsTextChanges() {
    let board = NoticeBoard()
    board.post("Before")
    board.post("Line 2 could not be read.", key: "settings:/p/.tm_properties:2")
    board.post("After")
    board.post("Line 2 still could not be read.", key: "settings:/p/.tm_properties:2")
    #expect(board.notices.map(\.text) == ["Before", "Line 2 still could not be read.", "After"])
  }

  @Test func theSameKeyedTextTwiceChangesNothing() {
    let board = NoticeBoard()
    nonisolated(unsafe) var announcements = 0
    let observer = NotificationCenter.default.addObserver(forName: NoticeBoard.didChangeNotification, object: board, queue: nil) { _ in
      announcements += 1
    }
    defer { NotificationCenter.default.removeObserver(observer) }

    board.post("Same", key: "k")
    board.post("Same", key: "k")
    #expect(board.notices.count == 1)
    #expect(announcements == 1)
  }

  @Test func dismissingByKeyPrefixTakesDownEveryNoticeAboutOneFile() {
    let board = NoticeBoard()
    board.post("Unkeyed")
    board.post("Line 2", key: "settings:/p/.tm_properties:2")
    board.post("Line 6", key: "settings:/p/.tm_properties:6")
    board.post("Other file", key: "settings:/q/.tm_properties:1")
    board.dismissNotices(withKeyPrefix: "settings:/p/.tm_properties:")
    #expect(board.notices.map(\.text) == ["Unkeyed", "Other file"])
    board.dismissNotices(withKeyPrefix: "settings:/nowhere:")
    #expect(board.notices.count == 2)
  }
}

import AppKit
import SwiftUI

/// The notices on the board, one line each with a Dismiss button, as a strip above a document's text.
/// Dismissing removes the notice from the board, so every window's strip loses it together.
struct NoticeStrip: View {
  var board: NoticeBoard

  var body: some View {
    VStack(spacing: 0) {
      ForEach(board.notices) { notice in
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Image(systemName: "info.circle")
            .foregroundStyle(.secondary)
          Text(notice.text)
            .font(.system(size: NSFont.smallSystemFontSize))
            .textSelection(.enabled)
          Spacer(minLength: 8)
          Button("Dismiss") {
            board.dismiss(notice)
          }
          .controlSize(.small)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        Divider()
      }
    }
    .background(.bar)
  }
}

/// The strip as an AppKit view, for the document view to stack above the text the way it stacks the find bar.
/// Its height follows its content through the hosting view's constraints, so a second notice makes it taller and the last dismissal lets the document view remove it.
@objc(OakNoticeStripView)
@MainActor
public final class NoticeStripView: NSView {
  public convenience override init(frame: NSRect) {
    self.init(frame: frame, board: .shared)
  }

  public init(frame: NSRect, board: NoticeBoard) {
    super.init(frame: frame)

    let hosting = NSHostingView(rootView: NoticeStrip(board: board))
    hosting.translatesAutoresizingMaskIntoConstraints = false
    addSubview(hosting)
    NSLayoutConstraint.activate([
      hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
      hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
      hosting.topAnchor.constraint(equalTo: topAnchor),
      hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("NoticeStripView is created in code")
  }
}

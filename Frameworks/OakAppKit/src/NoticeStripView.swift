import AppKit
import SwiftUI

/// The notices on the board, one line each with a Dismiss button, as a strip above a document's text.
/// Dismissing removes the notice from the board, so every window's strip loses it together.
struct NoticeStrip: View {
  var board: NoticeBoard

  @Environment(\.colorScheme) private var colorScheme

  /// The system yellow as it is in dark, where it stands out on the tint, and mixed toward black in light, where it did not.
  private var iconColor: Color {
    let yellow = Color(nsColor: .systemYellow)
    return colorScheme == .dark ? yellow : yellow.mix(with: .black, by: 0.4)
  }

  var body: some View {
    VStack(spacing: 0) {
      ForEach(board.notices) { notice in
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          // The icon takes the strip's color. The button stays the window's own, so it reads as a control and not as part of the warning.
          Image(systemName: "info.circle")
            .foregroundStyle(iconColor)
          Text(notice.text)
            .font(.body)
            .textSelection(.enabled)
            // Wraps rather than cuts off: a notice can name a path and a command, and both matter.
            .fixedSize(horizontal: false, vertical: true)
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
    // Tinted, unlike the find bar beside it, because this is the application speaking up rather than a tool the person summoned.
    .background(Color(nsColor: .systemYellow).opacity(0.18))
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

import AppKit
import SwiftUI

/// A notice's text as an AppKit text view, since a link inside SwiftUI's own Text neither changes the cursor nor says where it was clicked,
/// and a text field tracks the cursor over a link only while it is being edited. A text view does it at rest.
/// It wraps to the width it is given, lets the text be selected, shows the hand over a link, and sends a file link to Finder.
struct NoticeText: NSViewRepresentable {
  var text: NSAttributedString

  /// The text's size: title3, larger than the window's controls on purpose.
  /// This is the application interrupting about something that went wrong on its own, and the text carries a path, a version and a command to read.
  static let pointSize: CGFloat = NSFont.preferredFont(forTextStyle: .title3).pointSize

  /// Where the first line's baseline is from the top, for the banner to align the icon and the button to.
  /// SwiftUI takes a representable's baseline to be its top edge, so the banner is told instead, from the font's own metrics.
  static let firstBaseline: CGFloat = NSFont.systemFont(ofSize: pointSize).ascender

  func makeNSView(context: Context) -> NSTextView {
    let view = NSTextView()
    view.isEditable = false
    view.isSelectable = true
    view.drawsBackground = false
    view.textContainerInset = .zero
    view.textContainer?.lineFragmentPadding = 0
    view.textContainer?.widthTracksTextView = true
    view.isVerticallyResizable = true
    view.isHorizontallyResizable = false
    view.delegate = context.coordinator
    view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return view
  }

  func updateNSView(_ view: NSTextView, context: Context) {
    guard view.textStorage?.isEqual(to: text) != true else { return }
    view.textStorage?.setAttributedString(text)
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView view: NSTextView, context: Context) -> CGSize? {
    guard let width = proposal.width, width.isFinite, let container = view.textContainer, let layout = view.layoutManager else { return nil }
    container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
    layout.ensureLayout(for: container)
    return CGSize(width: width, height: layout.usedRect(for: container).height)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  /// A file link is shown in Finder rather than opened, since a notice names a file to point at it, not to edit it.
  /// Anything else goes to the system.
  final class Coordinator: NSObject, NSTextViewDelegate {
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
      guard let url = link as? URL, url.isFileURL else { return false }
      NSWorkspace.shared.activateFileViewerSelecting([url])
      return true
    }
  }
}

/// The notices on the board, each with a Dismiss button, as a banner above a document's text.
/// Dismissing removes the notice from the board, so every window's banner loses it together.
/// The banner reports its laid out height, since how many lines a notice wraps onto depends on the window's width.
struct NoticeBanner: View {
  var board: NoticeBoard
  var heightChanged: (CGFloat) -> Void

  @Environment(\.colorScheme) private var colorScheme

  /// The system yellow as it is in dark, where it stands out on the tint, and mixed toward black in light, where it did not.
  private var iconColor: Color {
    let yellow = Color(nsColor: .systemYellow)
    return colorScheme == .dark ? yellow : yellow.mix(with: .black, by: 0.4)
  }

  /// A notice's text is inline Markdown: a path or a command in backticks draws monospaced, a name in double asterisks draws medium,
  /// and a link draws as one. Text that is not Markdown draws as it is. The fonts are AppKit's, for the label that draws them.
  private func styled(_ text: String) -> NSAttributedString {
    let bodySize = NoticeText.pointSize
    var attributed: AttributedString
    if let parsed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
      attributed = parsed
    } else {
      attributed = AttributedString(text)
    }
    attributed.appKit.font = .systemFont(ofSize: bodySize)
    attributed.appKit.foregroundColor = .labelColor
    for run in attributed.runs {
      guard let intent = run.inlinePresentationIntent else { continue }
      if intent.contains(.code) {
        attributed[run.range].appKit.font = .monospacedSystemFont(ofSize: bodySize, weight: .regular)
      } else if intent.contains(.stronglyEmphasized) {
        attributed[run.range].appKit.font = .systemFont(ofSize: bodySize, weight: .medium)
      }
    }
    return NSAttributedString(attributed)
  }

  var body: some View {
    VStack(spacing: 0) {
      ForEach(board.notices) { notice in
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          // The icon takes the banner's color. The button stays the window's own, so it reads as a control and not as part of the warning.
          Image(systemName: "info.circle")
            .font(.title3)
            .foregroundStyle(iconColor)
          NoticeText(text: styled(notice.text))
            .alignmentGuide(.firstTextBaseline) { dimensions in dimensions[.top] + NoticeText.firstBaseline }
          Spacer(minLength: 8)
          Button("Dismiss") {
            board.dismiss(notice)
          }
          .controlSize(.small)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 16)
        Divider()
      }
    }
    // Tinted, unlike the find bar beside it, because this is the application speaking up rather than a tool the person summoned.
    .background(Color(nsColor: .systemYellow).opacity(0.18))
    .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: heightChanged)
  }
}

/// The banner as an AppKit view, for the document view to stack above the text the way it stacks the find bar.
/// The document view gives it the window's width and takes its height from a constraint this view keeps,
/// set from what SwiftUI laid out at that width. A hosting view's own intrinsic size is for an unbounded width,
/// one line per notice however narrow the window, which is why the height is measured rather than asked for.
@objc(OakNoticeBannerView)
@MainActor
public final class NoticeBannerView: NSView {
  private var heightConstraint: NSLayoutConstraint?

  public convenience override init(frame: NSRect) {
    self.init(frame: frame, board: .shared)
  }

  public init(frame: NSRect, board: NoticeBoard) {
    super.init(frame: frame)

    let hosting = NSHostingView(rootView: NoticeBanner(board: board) { [weak self] height in
      self?.contentHeightChanged(to: height)
    })
    hosting.sizingOptions = []
    hosting.translatesAutoresizingMaskIntoConstraints = false
    addSubview(hosting)

    let height = heightAnchor.constraint(equalToConstant: 0)
    heightConstraint = height
    NSLayoutConstraint.activate([
      hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
      hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
      hosting.topAnchor.constraint(equalTo: topAnchor),
      hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
      height,
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("NoticeBannerView is created in code")
  }

  private func contentHeightChanged(to height: CGFloat) {
    guard let heightConstraint, heightConstraint.constant != height else { return }
    heightConstraint.constant = height
    invalidateIntrinsicContentSize()
  }
}

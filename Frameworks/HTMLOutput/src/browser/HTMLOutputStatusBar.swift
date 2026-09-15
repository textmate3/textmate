import AppKit
import SwiftUI
import WebKit

/// The strip under a command's output.
///
/// What this replaces rebuilt its own constraints from visual format strings
/// every time the progress indicator changed shape, adding one indicator to
/// the view hierarchy and removing the other. Here the two are an `if`.
struct HTMLOutputStatusBar: View {
  @Bindable var status: HTMLOutputStatus

  var body: some View {
    VStack(spacing: 0) {
      Divider()
      HStack(spacing: 2) {
        Button(action: { status.goBack?() }) {
          Image(systemName: "chevron.left")
        }
        .disabled(!status.canGoBack)
        .help("Show the previous page")

        Button(action: { status.goForward?() }) {
          Image(systemName: "chevron.right")
        }
        .disabled(!status.canGoForward)
        .help("Show the next page")

        Divider()
          .frame(height: 15)
          .padding(.horizontal, 2)

        Text(status.text)
          .font(.system(size: NSFont.smallSystemFontSize))
          .lineLimit(1)
          .truncationMode(.middle)
          .frame(minWidth: 100, alignment: .leading)

        Spacer(minLength: 8)

        progress
      }
      .buttonStyle(.borderless)
      .padding(.horizontal, 3)
      .padding(.vertical, 4)
    }
    .background(.bar)
  }

  @ViewBuilder private var progress: some View {
    if status.showsSpinner {
      if status.isBusy {
        ProgressView()
          .controlSize(.small)
          .progressViewStyle(.circular)
      }
    } else {
      ProgressView(value: status.progress, total: 1)
        .controlSize(.small)
        .progressViewStyle(.linear)
        .frame(minWidth: 50, maxWidth: 150)
    }
  }
}

/// The strip as an AppKit view, keeping the interface the Objective-C++ around
/// it already sets, so the browser view lays out its web view and its status
/// bar exactly as before.
@objc(HOStatusBar)
public final class HOStatusBar: NSView {
  private let status = HTMLOutputStatus()

  /// Answers `goBack:` and `goForward:`, sent the way a control's target is,
  /// so a responder anywhere up the chain can take them. `WKWebView` is what
  /// this is set to, and it implements both.
  @objc public weak var delegate: AnyObject?

  public override init(frame: NSRect) {
    super.init(frame: frame)

    status.goBack = { [weak self] in
      guard let self else { return }
      NSApp.sendAction(#selector(WKWebView.goBack(_:)), to: delegate, from: self)
    }
    status.goForward = { [weak self] in
      guard let self else { return }
      NSApp.sendAction(#selector(WKWebView.goForward(_:)), to: delegate, from: self)
    }

    let hosting = NSHostingView(rootView: HTMLOutputStatusBar(status: status))
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
  required init?(coder: NSCoder) { fatalError("not from a nib") }

  // The same properties the Objective-C++ sets, forwarded to the model the
  // view observes. `statusText` keeps its name because a WKUIDelegate helper
  // sets it through a protocol that names it.
  @objc public var statusText: String {
    get { status.text }
    set { status.text = newValue }
  }

  @objc public var progress: Double {
    get { status.progress }
    set { status.progress = newValue }
  }

  @objc(isBusy) public var isBusy: Bool {
    get { status.isBusy }
    set { status.isBusy = newValue }
  }

  @objc public var canGoBack: Bool {
    get { status.canGoBack }
    set { status.canGoBack = newValue }
  }

  @objc public var canGoForward: Bool {
    get { status.canGoForward }
    set { status.canGoForward = newValue }
  }
}

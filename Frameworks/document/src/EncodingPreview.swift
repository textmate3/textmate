import AppKit
import SwiftUI

/// The document's bytes decoded in the chosen encoding, with the lines and
/// characters that decide the matter highlighted. The attributed string is
/// built on the Objective-C++ side, so this wraps a read-only NSTextView in a
/// scroll view rather than re-creating that rendering in SwiftUI.
struct EncodingPreview: NSViewRepresentable {
  let text: NSAttributedString

  func makeNSView(context: Context) -> NSScrollView {
    let textView = NSTextView(frame: .zero)
    textView.isEditable = false
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = true
    textView.autoresizingMask = [.width, .height]
    textView.textContainer?.widthTracksTextView = false
    let unbounded = CGFloat.greatestFiniteMagnitude
    textView.textContainer?.containerSize = NSSize(width: unbounded, height: unbounded)

    let scrollView = NSScrollView(frame: .zero)
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.borderType = .bezelBorder
    scrollView.documentView = textView
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView else { return }
    textView.textStorage?.setAttributedString(text)
  }
}

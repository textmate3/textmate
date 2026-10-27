import AppKit

/// The pieces every chooser lays out the same way. The Objective-C construction helpers these stand in for
/// carry C++ default arguments in their header, which Swift cannot read.
@MainActor
enum ChooserConstruction {
  static func statusBarFont() -> NSFont {
    let size = UserDefaults.standard.integer(forKey: "statusBarFontSize")
    return NSFont.messageFont(ofSize: size == 0 ? 12 : CGFloat(size))
  }

  static func separator() -> NSView {
    let box = NSBox(frame: .zero)
    box.boxType = .separator
    return box
  }

  static func label(_ text: String = "", font: NSFont? = nil, lineBreakMode: NSLineBreakMode = .byTruncatingMiddle) -> NSTextField {
    let field = NSTextField(labelWithString: text)
    field.cell?.lineBreakMode = lineBreakMode
    if let font {
      field.font = font
    }
    return field
  }

  static func addAutoLayoutViews(_ views: [NSView], to superview: NSView) {
    for view in views {
      view.translatesAutoresizingMaskIntoConstraints = false
      superview.addSubview(view)
    }
  }

  /// Makes the views a key view loop in the order given, each followed by the key views already chained
  /// inside it, so that tabbing walks the search field, the table and the scope bar around and around.
  static func setUpKeyViewLoop(_ superviews: [NSView]) {
    var seen = Set(superviews.map(ObjectIdentifier.init))
    var views: [NSView] = []
    for view in superviews {
      views.append(view)
      var subview = view
      while let next = subview.nextKeyView, next.isDescendant(of: view), seen.insert(ObjectIdentifier(next)).inserted {
        views.append(next)
        subview = next
      }
    }
    for (index, view) in views.enumerated() {
      view.nextKeyView = views.count == 1 ? nil : views[(index + 1) % views.count]
    }
  }
}

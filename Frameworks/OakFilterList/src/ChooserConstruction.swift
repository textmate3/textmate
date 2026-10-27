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
}

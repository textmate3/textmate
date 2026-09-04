import AppKit
import BundleSchema
import SwiftUI

/// A color as a theme writes it, `#RRGGBB` or `#RRGGBBAA`: the text field
/// holds the hex and the color well beside it shows and picks the same
/// color. Either side changes the other.
struct SchemaColorField: View {
  let key: SchemaKey
  let values: SchemaValues

  var body: some View {
    LabeledContent(key.name) {
      HStack(spacing: 6) {
        TextField(key.name, text: Binding(get: { values.string(key.name) ?? "" }, set: { values.setString($0, for: key.name) }))
          .labelsHidden()
          .font(.body.monospaced())
          .multilineTextAlignment(.trailing)
          .frame(width: 110)
        ColorPicker(
          key.name,
          selection: Binding(
            get: { SchemaColorField.color(from: values.string(key.name)) ?? .clear },
            set: { values.setString(SchemaColorField.hex(from: $0), for: key.name) }
          ),
          supportsOpacity: true
        )
        .labelsHidden()
      }
    }
  }

  /// `#RGB`, `#RRGGBB` or `#RRGGBBAA` to a color, a system color by its
  /// name, or nil for anything else.
  static func color(from text: String?) -> Color? {
    guard let text, ThemeValidator.isColor(text) else { return nil }
    if !text.hasPrefix("#") {
      return (NSColor.value(forKey: text) as? NSColor).map(Color.init)
    }
    var digits = String(text.dropFirst())
    if digits.count == 3 {
      digits = digits.map { "\($0)\($0)" }.joined()
    }
    let channels = stride(from: 0, to: digits.count, by: 2).compactMap { offset -> Double? in
      let start = digits.index(digits.startIndex, offsetBy: offset)
      let end = digits.index(start, offsetBy: 2)
      return UInt8(digits[start..<end], radix: 16).map { Double($0) / 255 }
    }
    guard channels.count >= 3 else { return nil }
    return Color(.sRGB, red: channels[0], green: channels[1], blue: channels[2], opacity: channels.count == 4 ? channels[3] : 1)
  }

  /// A color back to `#RRGGBB`, with the alpha appended when it is not full.
  static func hex(from color: Color) -> String {
    guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return "" }
    let channels = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent].map { Int(($0 * 255).rounded()) }
    var text = String(format: "#%02X%02X%02X", channels[0], channels[1], channels[2])
    if rgb.alphaComponent < 1 {
      text += String(format: "%02X", Int((rgb.alphaComponent * 255).rounded()))
    }
    return text
  }
}

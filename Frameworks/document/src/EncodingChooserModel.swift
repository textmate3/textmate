import AppKit
import Observation

/// One encoding the chooser offers: the iconv name the document layer uses and
/// the name a person reads.
struct EncodingChoice: Identifiable, Hashable {
  let code: String
  let name: String

  var id: String { code }
}

/// What the encoding chooser shows and what the person changes. The Objective-C
/// side writes the preview and reads the answer through EncodingChooserController.
@Observable
@MainActor
final class EncodingChooserModel {
  var displayName = "untitled"
  var encodings: [EncodingChoice] = []
  var selectedEncoding = "ISO-8859-1"
  var preview = NSAttributedString()
  var acceptableEncoding = true
  var trainClassifier = true

  /// Called when the person picks another encoding, so the host can rebuild
  /// the preview in that encoding.
  var selectionChanged: ((String) -> Void)?
}

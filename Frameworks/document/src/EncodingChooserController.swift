import AppKit
import SwiftUI

/// The Objective-C face of the encoding chooser. EncodingWindowController owns
/// the bytes and the transcoding, creates one of these as its window's content,
/// pushes the preview in, and reads the answer out. Nothing here knows about
/// the document.
@objc(OakEncodingChooserController)
@MainActor
public final class EncodingChooserController: NSViewController {
	private let model = EncodingChooserModel()

	@objc public var openHandler: (() -> Void)?
	@objc public var cancelHandler: (() -> Void)?

	/// Called with the newly picked encoding, before the host sets a new preview.
	@objc public var selectionHandler: ((String) -> Void)? {
		get { model.selectionChanged }
		set { model.selectionChanged = newValue }
	}

	@objc public var displayName: String {
		get { model.displayName }
		set { model.displayName = newValue }
	}

	@objc public var selectedEncoding: String {
		get { model.selectedEncoding }
		set { model.selectedEncoding = newValue }
	}

	@objc public var preview: NSAttributedString {
		get { model.preview }
		set { model.preview = newValue }
	}

	@objc public var acceptableEncoding: Bool {
		get { model.acceptableEncoding }
		set { model.acceptableEncoding = newValue }
	}

	@objc public var trainClassifier: Bool {
		get { model.trainClassifier }
		set { model.trainClassifier = newValue }
	}

	/// The encodings to offer, as parallel lists of iconv names and display names.
	@objc public func setEncodings(codes: [String], names: [String]) {
		model.encodings = zip(codes, names).map { EncodingChoice(code: $0, name: $1) }
	}

	public override func loadView() {
		view = NSHostingView(
			rootView: EncodingChooserView(
				model: model,
				onOpen: { [weak self] in self?.openHandler?() },
				onCancel: { [weak self] in self?.cancelHandler?() }
			))
	}
}

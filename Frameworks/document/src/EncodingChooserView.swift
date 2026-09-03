import SwiftUI

/// The sheet shown when a file's bytes are not valid in the expected encoding:
/// pick an encoding, check the preview, choose whether the classifier learns
/// from it, then open or cancel.
struct EncodingChooserView: View {
	@Bindable var model: EncodingChooserModel
	let onOpen: () -> Void
	let onCancel: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Unknown Encoding")
				.font(.headline)

			Text("The file “\(model.displayName)” contains characters with unknown encoding.\nPlease select the encoding which should be used to open the file.\nThe contents of the file is shown below with the relevant lines highlighted.\nBefore proceeding, check that the chosen encoding makes the preview look correct.")
				.fixedSize(horizontal: false, vertical: true)

			Picker("Encoding:", selection: $model.selectedEncoding) {
				ForEach(model.encodings) { choice in
					Text(choice.name).tag(choice.code)
				}
			}
			.onChange(of: model.selectedEncoding) { _, encoding in
				model.selectionChanged?(encoding)
			}

			EncodingPreview(text: model.preview)
				.frame(minHeight: 160)

			Toggle("Use document for training encoding classifier", isOn: $model.trainClassifier)

			HStack {
				Spacer()
				Button("Cancel", action: onCancel)
					.keyboardShortcut(.cancelAction)
				Button("Open", action: onOpen)
					.keyboardShortcut(.defaultAction)
					.disabled(!model.acceptableEncoding)
			}
		}
		.padding(20)
		.frame(minWidth: 560, minHeight: 420)
	}
}

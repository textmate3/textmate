import OakFoundation
import SwiftUI

/// The About page of the About window: icon, name, version, where to read more,
/// and the copyright line. Everything it shows comes from ApplicationInfo.
struct AboutView: View {
	let info: ApplicationInfo

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack(spacing: 16) {
				Image(nsImage: NSApp.applicationIconImage)
					.resizable()
					.frame(width: 96, height: 96)
				VStack(alignment: .leading, spacing: 4) {
					Text("TextMate")
						.font(.largeTitle.bold())
					Text("Version \(info.shortVersion)")
						.foregroundStyle(.secondary)
				}
			}

			Text("The manual is a work in progress and can be found at [macromates.com/textmate/manual](https://macromates.com/textmate/manual/). The MacroMates Blog has a [TextMate 2 category](https://blog.macromates.com/categories/textmate-2/).")

			Text("There is a [FAQ](https://github.com/textmate/textmate/wiki/FAQ) and [hidden settings](https://github.com/textmate/textmate/wiki/Hidden-Settings) page.")

			Text("For comments, questions, and general feedback see [macromates.com/support](https://macromates.com/support).")

			Text("TextMate is a trademark of Allan Odgaard and the program is \(info.copyright).")
				.font(.footnote)
				.foregroundStyle(.secondary)
				.italic()

			Spacer()
		}
		.padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}
}

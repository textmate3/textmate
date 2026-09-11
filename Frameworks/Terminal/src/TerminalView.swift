import SwiftUI

/// The plainest thing that shows a shell and takes a line at a time.
///
/// A terminal view draws a grid of styled cells and sends every keystroke as
/// it happens. This draws text and sends a line when return is pressed, which
/// is enough to see the arrangement work and is not enough to be a terminal.
/// The difference is the emulator, and what that would take is written down in
/// `TerminalOutput`.
struct TerminalView: View {
  @ObservedObject var session: TerminalSession

  var body: some View {
    VStack(spacing: 0) {
      ScrollViewReader { proxy in
        ScrollView {
          Text(session.output)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .id("output")
        }
        .onChange(of: session.output) { _, _ in
          proxy.scrollTo("output", anchor: .bottom)
        }
      }

      Divider()

      HStack(spacing: 6) {
        Image(systemName: "chevron.right")
          .foregroundStyle(.secondary)
        TextField("", text: $session.input)
          .textFieldStyle(.plain)
          .font(.system(.body, design: .monospaced))
          .onSubmit { session.send() }
          .disabled(!session.isRunning)
      }
      .padding(8)
    }
    .frame(minWidth: 540, minHeight: 320)
  }
}

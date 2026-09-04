import SwiftUI

/// The macro's steps as a numbered list in the order they play, with a bar
/// underneath to take a step away or move it.
struct MacroStepsView: View {
  let document: MacroDocument
  @Binding var selection: MacroStep.ID?

  var body: some View {
    VStack(spacing: 0) {
      List(selection: $selection) {
        ForEach(Array(document.steps.enumerated()), id: \.element.id) { index, step in
          HStack {
            Text("\(index + 1)")
              .foregroundStyle(.secondary)
              .monospacedDigit()
              .frame(width: 28, alignment: .trailing)
            Text(step.title)
              .lineLimit(1)
              .truncationMode(.tail)
          }
          .tag(step.id)
          .contextMenu {
            Button("Move Up") { document.move(step.id, by: -1) }
            Button("Move Down") { document.move(step.id, by: 1) }
            Divider()
            Button("Remove", role: .destructive) { remove(step.id) }
          }
        }
      }
      .listStyle(.inset)
      Divider()
      bar
    }
  }

  private var bar: some View {
    HStack(spacing: 4) {
      Button {
        if let selection { remove(selection) }
      } label: {
        Image(systemName: "minus")
      }
      .disabled(selection == nil)
      .help("Remove the selected step")

      Spacer()

      Button {
        if let selection { document.move(selection, by: -1) }
      } label: {
        Image(systemName: "chevron.up")
      }
      .disabled(!(selection.map { document.canMove($0, by: -1) } ?? false))
      .help("Move the selected step up")

      Button {
        if let selection { document.move(selection, by: 1) }
      } label: {
        Image(systemName: "chevron.down")
      }
      .disabled(!(selection.map { document.canMove($0, by: 1) } ?? false))
      .help("Move the selected step down")
    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
  }

  private func remove(_ id: MacroStep.ID) {
    document.remove(id)
    if selection == id { selection = nil }
  }
}

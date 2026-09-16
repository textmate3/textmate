import SwiftUI

/// One file in the list: whether to commit it, what the system says about it,
/// its path, and a way to see its diff.
struct CommitFileRow: View {
  @Bindable var item: CommitItem
  let showsDiffButton: Bool
  let onShowDiff: () -> Void

  var body: some View {
    HStack(spacing: 5) {
      Toggle("", isOn: $item.isIncluded)
        .labelsHidden()
        .controlSize(.small)
        .accessibilityLabel("Commit \(item.path)")

      CommitStatusLabel(columns: item.statusColumns)

      Text(item.path)
        .lineLimit(1)
        .truncationMode(.head)
        .help(item.path)

      Spacer(minLength: 5)

      if showsDiffButton {
        Button("Diff", action: onShowDiff)
          .controlSize(.mini)
          .frame(width: 40)
      }
    }
    .contentShape(.rect)
  }
}

/// The status letters, one boxed cell each, in a monospaced font so a column
/// lines up down the list.
struct CommitStatusLabel: View {
  let columns: [CommitStatusColumn]

  var body: some View {
    HStack(spacing: 2) {
      ForEach(columns) { column in
        Text(column.isBlank ? " " : String(column.letter))
          .font(.system(size: NSFont.smallSystemFontSize, weight: .medium, design: .monospaced))
          .foregroundStyle(column.foreground)
          .frame(width: 13)
          .padding(.vertical, 1)
          .background(column.isBlank ? .clear : column.background)
          .clipShape(.rect(cornerRadius: 2))
      }
    }
    .accessibilityLabel("Status \(columns.map { String($0.letter) }.joined())")
  }
}

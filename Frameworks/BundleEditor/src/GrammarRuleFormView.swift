import GrammarSchema
import SwiftUI

/// The fields of one rule, chosen by its shape: a match rule shows match and
/// captures, a region shows begin and end with their captures, an include
/// shows the reference. Labels and help come from the schema's key table.
/// A repository entry or injection also shows its name.
struct GrammarRuleFormView: View {
  @Bindable var rule: GrammarRule
  var entry: GrammarNamedRule?

  var body: some View {
    Form {
      Section {
        if let entry {
          GrammarNamedRuleField(entry: entry)
        }
        field("name", text: $rule.scopeName)
        switch rule.shape {
        case .match:
          field("match", text: $rule.match)
        case .beginEnd:
          field("begin", text: $rule.begin)
          field("end", text: $rule.end)
          field("contentName", text: $rule.contentName)
          flag("applyEndPatternLast", isOn: $rule.applyEndPatternLast)
        case .beginWhile:
          field("begin", text: $rule.begin)
          field("while", text: $rule.whilePattern)
          field("contentName", text: $rule.contentName)
        case .include:
          field("include", text: $rule.include)
        case .patterns, nil:
          EmptyView()
        }
        flag("disabled", isOn: $rule.disabled)
        field("comment", text: $rule.comment)
      }

      switch rule.shape {
      case .match:
        captures("captures", \.captures)
      case .beginEnd:
        captures("beginCaptures", \.beginCaptures)
        captures("endCaptures", \.endCaptures)
        captures("captures", \.captures)
      case .beginWhile:
        captures("beginCaptures", \.beginCaptures)
        captures("whileCaptures", \.whileCaptures)
      case .include, .patterns, nil:
        EmptyView()
      }

      if !rule.patterns.isEmpty {
        Section("patterns") {
          Text("\(rule.patterns.count) nested patterns, in the outline")
            .foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
  }

  /// A labeled text field that wraps, since patterns run long, with the
  /// schema's help on hover. An emptied field removes the key.
  private func field(_ key: String, text: Binding<String?>) -> some View {
    LabeledContent(key) {
      TextField(key, text: Binding(get: { text.wrappedValue ?? "" }, set: { text.wrappedValue = $0.isEmpty ? nil : $0 }), axis: .vertical)
        .labelsHidden()
        .lineLimit(1...6)
        .font(.body.monospaced())
        .multilineTextAlignment(.trailing)
    }
    .help(GrammarSchema.ruleKey(named: key)?.summary ?? "")
  }

  private func flag(_ key: String, isOn: Binding<Bool?>) -> some View {
    Toggle(key, isOn: Binding(get: { isOn.wrappedValue ?? false }, set: { isOn.wrappedValue = $0 ? true : nil }))
      .help(GrammarSchema.ruleKey(named: key)?.summary ?? "")
  }

  /// A captures table with a row per capture and a button that adds the
  /// next number. Shown even when empty for the shapes that take one, so a
  /// capture can be added.
  private func captures(_ key: String, _ table: ReferenceWritableKeyPath<GrammarRule, [GrammarCapture]>) -> some View {
    Section {
      ForEach(rule[keyPath: table]) { capture in
        GrammarCaptureRow(capture: capture) {
          rule[keyPath: table].removeAll { $0.id == capture.id }
        }
      }
    } header: {
      HStack {
        Text(key)
        Spacer()
        Button {
          let numbers = rule[keyPath: table].compactMap { Int($0.key) }
          let next = (numbers.max() ?? 0) + 1
          rule[keyPath: table].append(GrammarCapture(key: String(next), rule: GrammarRule()))
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.borderless)
        .help("Add capture \((rule[keyPath: table].compactMap { Int($0.key) }.max() ?? 0) + 1)")
      }
    }
  }
}

import GrammarSchema
import SwiftUI

/// The fields of one rule, chosen by its shape: a match rule shows match and
/// captures, a region shows begin and end with their captures, an include
/// shows the reference. Labels and help come from the schema's key table.
struct GrammarRuleFormView: View {
  @Bindable var rule: GrammarRule

  var body: some View {
    Form {
      Section {
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
        captures("captures", rule.captures)
      case .beginEnd:
        captures("beginCaptures", rule.beginCaptures)
        captures("endCaptures", rule.endCaptures)
        captures("captures", rule.captures)
      case .beginWhile:
        captures("beginCaptures", rule.beginCaptures)
        captures("whileCaptures", rule.whileCaptures)
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

  private func field(_ key: String, text: Binding<String?>) -> some View {
    TextField(key, text: Binding(get: { text.wrappedValue ?? "" }, set: { text.wrappedValue = $0.isEmpty ? nil : $0 }))
      .font(.body.monospaced())
      .help(GrammarSchema.ruleKey(named: key)?.summary ?? "")
  }

  private func flag(_ key: String, isOn: Binding<Bool?>) -> some View {
    Toggle(key, isOn: Binding(get: { isOn.wrappedValue ?? false }, set: { isOn.wrappedValue = $0 ? true : nil }))
      .help(GrammarSchema.ruleKey(named: key)?.summary ?? "")
  }

  @ViewBuilder
  private func captures(_ key: String, _ captures: [GrammarCapture]) -> some View {
    if !captures.isEmpty {
      Section(key) {
        ForEach(captures) { capture in
          GrammarCaptureRow(capture: capture)
        }
      }
    }
  }
}

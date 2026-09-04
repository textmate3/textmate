import BundleSchema
import SwiftUI

/// One step: its selector, and its argument as what it is. Typed text is a
/// field. A command's options are rows, the text ones editable, the rest
/// shown as they are. Macros are recorded rather than written, so the
/// selector itself is shown, not edited.
struct MacroStepFormView: View {
  @Bindable var step: MacroStep

  var body: some View {
    Form {
      Section {
        LabeledContent("command") {
          Text(step.command)
            .font(.body.monospaced())
            .textSelection(.enabled)
        }
        .help(MacroSchema.stepKey(named: "command")?.summary ?? "")
      }
      Section("argument") {
        if step.argumentOptions != nil {
          options
        } else {
          LabeledContent("text") {
            TextField("text", text: Binding(get: { step.argumentText ?? "" }, set: { step.argumentText = $0 }))
              .labelsHidden()
              .font(.body.monospaced())
              .multilineTextAlignment(.trailing)
          }
          .help(MacroSchema.stepKey(named: "argument")?.summary ?? "")
        }
      }
    }
    .formStyle(.grouped)
  }

  @ViewBuilder
  private var options: some View {
    let options = step.argumentOptions ?? [:]
    ForEach(options.keys.sorted(), id: \.self) { key in
      LabeledContent(key) {
        if let text = options[key] as? String {
          TextField(key, text: Binding(get: { text }, set: { step.setOption($0, for: key) }))
            .labelsHidden()
            .font(.body.monospaced())
            .multilineTextAlignment(.trailing)
        } else {
          Text(describe(options[key]))
            .font(.body.monospaced())
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private func describe(_ value: Any?) -> String {
    if let flag = value as? Bool { return flag ? "true" : "false" }
    if let number = value as? NSNumber { return number.stringValue }
    if let list = value as? [Any] { return "\(list.count) items" }
    if let table = value as? [String: Any] { return "\(table.count) keys" }
    return String(describing: value ?? "")
  }
}

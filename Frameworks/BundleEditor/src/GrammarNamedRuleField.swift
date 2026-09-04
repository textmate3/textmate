import SwiftUI

/// The name a repository entry is included by, or the scope selector an
/// injection applies to, editable above the rule's own fields.
struct GrammarNamedRuleField: View {
  @Bindable var entry: GrammarNamedRule

  var body: some View {
    LabeledContent("repository name") {
      TextField("name", text: $entry.name)
        .labelsHidden()
        .font(.body.monospaced())
        .multilineTextAlignment(.leading)
    }
    .help("What patterns include this rule by, as #name.")
  }
}

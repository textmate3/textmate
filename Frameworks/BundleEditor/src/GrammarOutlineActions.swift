import BundleSchema

/// What the outline's bar and context menus can do to the document, handed
/// down so the rows do not reach into the document themselves.
struct GrammarOutlineActions {
  /// Where a new rule goes.
  enum Placement: Equatable {
    /// After the rule with this identifier, in the same list.
    case after(GrammarRule.ID?)
    /// At the end of this rule's own patterns.
    case inside(GrammarRule.ID)
    /// A new repository entry.
    case repository
  }

  let add: (GrammarRuleShape, Placement) -> Void
  let remove: (GrammarRule.ID) -> Void
  let move: (GrammarRule.ID, Int) -> Void
}

import SwiftUI

extension Binding where Value == Bool {
  /// The same flag the other way around: the defaults say "disable", the
  /// check boxes say "do".
  var negated: Binding<Bool> {
    Binding(
      get: { !wrappedValue },
      set: { wrappedValue = !$0 }
    )
  }
}

import AppKit
import SwiftUI

/// The Updates pane. Sparkle reads the two check settings straight from
/// defaults, the application's updater delegate reads the channel, and Check
/// Now is a nil target action that travels the responder chain to the
/// application delegate, which is what knows the updater.
struct UpdatesView: View {
  @AppStorage("SUEnableAutomaticChecks") private var checksAutomatically = false
  @AppStorage("SUAutomaticallyUpdate") private var downloadsAutomatically = false
  @AppStorage("updateChannel") private var channel = "release"
  @State private var lastCheck = UpdatesView.storedLastCheck

  private static let lastCheckKey = "SULastCheckTime"

  private static var storedLastCheck: Date? {
    UserDefaults.standard.object(forKey: lastCheckKey) as? Date
  }

  /// Sparkle stores whether downloads happen on their own. The pane asks the
  /// question the other way around, the way it always has.
  private var asksBeforeDownloading: Binding<Bool> {
    Binding(
      get: { !downloadsAutomatically },
      set: { downloadsAutomatically = !$0 }
    )
  }

  var body: some View {
    Form {
      LabeledContent("Software update:") {
        VStack(alignment: .leading, spacing: 8) {
          Toggle("Check for updates automatically", isOn: $checksAutomatically)
          Toggle("Ask before downloading updates", isOn: asksBeforeDownloading)
            .disabled(!checksAutomatically)
        }
      }

      Picker("Update channel:", selection: $channel) {
        Text("Release").tag("release")
        Text("Beta, the nightlies").tag("beta")
        Text("Alpha, the development team").tag("alpha")
      }
      .fixedSize()

      Divider()
        .padding(.vertical, 4)

      LabeledContent("Last check:") {
        VStack(alignment: .leading, spacing: 8) {
          TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(lastCheckDescription(at: context.date))
          }
          Button("Check Now") {
            NSApp.sendAction(NSSelectorFromString("checkForUpdates:"), to: nil, from: nil)
          }
        }
      }
    }
    .formStyle(.columns)
    .padding(20)
    .frame(width: 600)
    .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
      lastCheck = UpdatesView.storedLastCheck
    }
  }

  private func lastCheckDescription(at now: Date) -> String {
    guard let lastCheck else { return "Never" }
    if now.timeIntervalSince(lastCheck) < 5 { return "Just now" }
    return lastCheck.formatted(.relative(presentation: .numeric))
  }
}

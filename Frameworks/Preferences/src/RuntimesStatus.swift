import AppKit
import Observation

/// Where one language's runtime stands, as the Runtimes pane shows it: the bundle that carries it, the version the application wants,
/// the one bundle commands run on now, the manager behind it, and every version the manager has or could fetch.
struct LanguageRuntime: Sendable {
  let language: String
  let managerName: String
  let bundleIdentifier: UUID

  var pinnedVersion = ""
  var inUse: String?
  var bundleName: String?
  var isBundleInstalled = false
  var isBundleInstalling = false
  var managerPath: String?
  var managerVersion: String?
  var versions: [RuntimeVersion] = []
  var listingProblem: String?
  var isRefreshing = false
  var isResolving = false

  var isPinnedInstalled: Bool {
    versions.contains { $0.version == pinnedVersion && $0.isInstalled }
  }

  var installedVersions: [RuntimeVersion] {
    versions.filter(\.isInstalled)
  }

  /// What the manager could fetch that is newer than the version the application wants.
  var newerThanPinned: [RuntimeVersion] {
    versions.filter { RuntimeListParser.isNewer($0.version, than: pinnedVersion) }
  }

  mutating func apply(manager: RuntimeManager?, version: String?, listing: Result<[RuntimeVersion], any Error>?) {
    managerPath = manager?.path
    managerVersion = version
    switch listing {
    case nil:
      versions = []
      listingProblem = "\(managerName) is not on this machine, and the \(language) bundle that carries one is not installed."
    case .success(let found):
      versions = found
      listingProblem = nil
    case .failure(let error):
      versions = []
      listingProblem = error.localizedDescription
    }
    isRefreshing = false
  }
}

/// The two runtimes, read from the application and from their managers, and the actions the pane offers.
/// The facts come from `RuntimeInfo`, the lists from running the managers off the main thread,
/// and a refresh follows whenever the application reports a runtime settled or the catalog reports a bundle changed.
@MainActor
@Observable
final class RuntimesStatus {
  var ruby = LanguageRuntime(language: "Ruby", managerName: "rv", bundleIdentifier: RuntimeInfo.rubyBundleIdentifier)
  var python = LanguageRuntime(language: "Python", managerName: "uv", bundleIdentifier: RuntimeInfo.pythonBundleIdentifier)

  @ObservationIgnored private var observers: [any NSObjectProtocol] = []

  /// Languages whose bundle this pane asked to install, so the runtime is resolved as soon as the bundle arrives.
  @ObservationIgnored private var awaitingBundle: Set<String> = []

  init() {
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(forName: .TMRuntimeDidActivate, object: nil, queue: .main) { [weak self] notification in
        let language = notification.userInfo?["language"] as? String
        MainActor.assumeIsolated {
          self?.runtimeDidActivate(language)
        }
      })
    observers.append(
      center.addObserver(forName: .BundleCatalogDidChange, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.bundlesChanged()
        }
      })
  }

  isolated deinit {
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  func refresh() {
    ruby.pinnedVersion = RuntimeInfo.rubyPinnedVersion
    ruby.inUse = RuntimeInfo.rubyInUse
    python.pinnedVersion = RuntimeInfo.pythonPinnedVersion
    python.inUse = RuntimeInfo.pythonInUse
    bundlesChanged()
    listVersions()
  }

  /// Installs the bundle that carries the runtime, and resolves the runtime once it is there.
  func installBundle(for language: String) {
    awaitingBundle.insert(language)
    BundleCatalog.sharedInstance.install(language == "Ruby" ? ruby.bundleIdentifier : python.bundleIdentifier)
  }

  /// Asks the application to resolve the runtime again, which installs the pinned version when it is missing and remakes the environment.
  func resolve(_ language: String) {
    if language == "Ruby" {
      ruby.isResolving = true
    } else {
      python.isResolving = true
    }
    RuntimeInfo.requestActivation(forLanguage: language)
  }

  func reveal(_ path: String) {
    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
  }

  private func runtimeDidActivate(_ language: String?) {
    if language == "Ruby" {
      ruby.isResolving = false
    } else if language == "Python" {
      python.isResolving = false
    }
    refresh()
  }

  private func bundlesChanged() {
    let bundles = BundleCatalog.sharedInstance.bundles
    apply(bundles.first { $0.identifier == ruby.bundleIdentifier }, to: &ruby)
    apply(bundles.first { $0.identifier == python.bundleIdentifier }, to: &python)

    for language in awaitingBundle where (language == "Ruby" ? ruby : python).isBundleInstalled {
      awaitingBundle.remove(language)
      resolve(language)
    }
  }

  private func apply(_ bundle: CatalogBundle?, to runtime: inout LanguageRuntime) {
    runtime.bundleName = bundle?.name
    runtime.isBundleInstalled = bundle?.isInstalled ?? false
    runtime.isBundleInstalling = bundle?.isInstalling ?? false
  }

  private func listVersions() {
    ruby.isRefreshing = true
    python.isRefreshing = true
    let rubySupport = RuntimeInfo.rubyBundleSupportPath
    let pythonSupport = RuntimeInfo.pythonBundleSupportPath

    Task.detached {
      let rubyManager = RuntimeManager.find("rv", bundleSupportPath: rubySupport)
      let rubyManagerVersion = rubyManager?.version()
      let rubies: Result<[RuntimeVersion], any Error>? = rubyManager.map { manager in Result { try manager.rubyVersions() } }

      let pythonManager = RuntimeManager.find("uv", bundleSupportPath: pythonSupport)
      let pythonManagerVersion = pythonManager?.version()
      let pythons: Result<[RuntimeVersion], any Error>? = pythonManager.map { manager in Result { try manager.pythonVersions() } }

      await MainActor.run {
        self.ruby.apply(manager: rubyManager, version: rubyManagerVersion, listing: rubies)
        self.python.apply(manager: pythonManager, version: pythonManagerVersion, listing: pythons)
      }
    }
  }
}

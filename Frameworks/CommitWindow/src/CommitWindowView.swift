import SwiftUI

/// The commit window: a message field that is TextMate's own editor, an
/// optional list of files to include, and the buttons.
///
/// What this replaces was three hundred lines of Auto Layout, rebuilt by hand
/// every time the file list was shown or hidden, with the height animated
/// through a constraint that was removed and recreated four times per toggle.
/// Showing and hiding a section is one `if` here.
struct CommitWindowView: View {
  @Bindable var model: CommitWindowModel
  @State private var message = CommitMessageDocument()
  @State private var selection: CommitItem.ID?

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      CommitMessageEditor(document: message)
        .frame(minHeight: 195)
      Divider()
      disclosure

      if model.showsFileList {
        Divider()
        fileList
        Divider()
        actionBar
      }

      buttons
    }
    .frame(minWidth: 400)
    .onAppear {
      message.load(
        content: model.arguments.log,
        fileType: CommitMessageView.fileType(forSCMName: model.environment["TM_SCM_NAME"] ?? ""),
        virtualPath: (model.projectDirectory as NSString).appendingPathComponent("commit-message.txt")
      )
    }
    .alert(model.failure?.title ?? "", isPresented: .init(get: { model.failure != nil }, set: { if !$0 { model.failure = nil } })) {
      Button("OK") { model.failure = nil }
    } message: {
      Text(model.failure?.detail ?? "")
    }
  }

  // ==========
  // = Pieces =
  // ==========

  private var header: some View {
    HStack {
      Spacer()
      Menu("Previous Commit Messages") {
        ForEach(model.recentMessages, id: \.self) { previous in
          Button(CommitMessageHistory.title(of: previous)) { message.content = previous }
            .help(previous)
        }
        if !model.recentMessages.isEmpty {
          Divider()
          Button("Clear Menu") { model.clearHistory() }
        }
      }
      .disabled(model.recentMessages.isEmpty)
      .frame(minWidth: 200)
      .fixedSize()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
  }

  private var disclosure: some View {
    HStack {
      Toggle(isOn: $model.showsFileList) {
        Text(model.showsFileList ? "Hide file list" : "Show file list")
      }
      .toggleStyle(.button)
      .buttonStyle(.accessoryBarAction)
      .accessibilityLabel("Show file list")

      Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
  }

  private var fileList: some View {
    List(selection: $selection) {
      ForEach(model.items) { item in
        CommitFileRow(item: item, showsDiffButton: !model.arguments.diffCommand.isEmpty) {
          model.showDiff(of: item)
        }
        .tag(item.id)
      }
    }
    .listStyle(.bordered(alternatesRowBackgrounds: true))
    .frame(height: 190)
    .contextMenu(forSelectionType: CommitItem.ID.self) { ids in
      contextMenu(for: ids.first)
    } primaryAction: { ids in
      if let item = item(ids.first) { model.showDiff(of: item) }
    }
  }

  private var actionBar: some View {
    HStack {
      Menu {
        contextMenu(for: selection)
      } label: {
        Label("Actions", systemImage: "ellipsis.circle")
      }
      .menuStyle(.borderlessButton)
      .fixedSize()

      Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
  }

  private var buttons: some View {
    HStack {
      Spacer()
      Button("Cancel") { model.cancel() }
        .keyboardShortcut(".", modifiers: .command)
      Button(model.commitButtonTitle) { model.commit(message: message.content, andContinue: model.continues) }
        .keyboardShortcut(.return, modifiers: model.continues ? [.command, .option] : .command)
        .buttonStyle(.borderedProminent)
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 12)
    .padding(.top, model.showsFileList ? 0 : 12)
  }

  @ViewBuilder private func contextMenu(for id: CommitItem.ID?) -> some View {
    if let item = item(id) {
      ForEach(model.arguments.actions) { action in
        Button(model.title(of: action, for: item)) { model.perform(action, on: item) }
          .disabled(!action.applies(to: item))
      }
      if !model.arguments.actions.isEmpty {
        Divider()
      }
    }
    Button("Check All") { model.setAllIncluded(true) }
    Button("Uncheck All") { model.setAllIncluded(false) }
  }

  private func item(_ id: CommitItem.ID?) -> CommitItem? {
    guard let id else { return nil }
    return model.items.first { $0.id == id }
  }
}

/// A handle on the editor, so the window can read what was typed and replace it
/// with a previous message.
///
/// The editor owns the text, not this. Mirroring it into a SwiftUI property
/// would mean writing it back on every update, which would fight whoever is
/// typing.
@Observable
final class CommitMessageDocument {
  @ObservationIgnored fileprivate weak var view: CommitMessageView?
  @ObservationIgnored private var pending: String?
  @ObservationIgnored fileprivate var fileType = "text.plain"
  @ObservationIgnored fileprivate var virtualPath = ""

  /// Bumped when a whole document is loaded, which is the only time the
  /// representable should write to the editor.
  @ObservationIgnored fileprivate var generation = 0

  var content: String {
    get { view?.content ?? pending ?? "" }
    set {
      pending = newValue
      generation += 1
      view?.setContent(newValue, fileType: fileType, virtualPath: virtualPath)
    }
  }

  func load(content: String, fileType: String, virtualPath: String) {
    self.fileType = fileType
    self.virtualPath = virtualPath
    self.content = content
  }

  fileprivate func adopt(_ view: CommitMessageView) {
    self.view = view
    view.setContent(pending ?? "", fileType: fileType, virtualPath: virtualPath)
  }
}

/// TextMate's own editor, as a SwiftUI view.
struct CommitMessageEditor: NSViewRepresentable {
  let document: CommitMessageDocument

  func makeNSView(context: Context) -> CommitMessageView {
    let view = CommitMessageView(frame: .zero)
    document.adopt(view)
    context.coordinator.generation = document.generation
    DispatchQueue.main.async { view.makeFirstResponder() }
    return view
  }

  func updateNSView(_ view: CommitMessageView, context: Context) {
    guard context.coordinator.generation != document.generation else { return }
    context.coordinator.generation = document.generation
    view.setContent(document.content, fileType: document.fileType, virtualPath: document.virtualPath)
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator {
    var generation = -1
  }
}

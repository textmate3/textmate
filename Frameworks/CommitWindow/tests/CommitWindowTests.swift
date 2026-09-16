import Testing
import Foundation
@testable import CommitWindow

// The window had no tests at all. These cover what it decides rather than what
// it draws: how the tool's arguments are read, which files start checked, what
// the commit button says, what goes back down the socket, and how a previous
// message is remembered.

@Suite struct CommitArgumentsTests {
  /// The arguments arrive as the tool's own argv, so the first is its path.
  private func parse(_ arguments: String...) -> CommitArguments {
    CommitArguments(argv: ["/path/to/CommitWindowTool"] + arguments)
  }

  @Test func anythingUnrecognizedIsAFileToCommit() {
    let arguments = parse("--status", "M:A", "one.txt", "two.txt")
    #expect(arguments.paths == ["one.txt", "two.txt"])
  }

  @Test func statusesArriveSeparatedByColons() {
    #expect(parse("--status", "M:A:?").statuses == ["M", "A", "?"])
  }

  @Test func theLogIsTheMessageToStartWith() {
    #expect(parse("--log", "Fix the thing").log == "Fix the thing")
  }

  @Test func theCommitButtonCanBeRenamed() {
    #expect(parse("--commit-button-title", "Shelve").commitButtonPrefix == "Shelve")
  }

  @Test func withoutOneItIsCommit() {
    #expect(parse().commitButtonPrefix == "Commit")
  }

  @Test func theContinueButtonIsAskedForOrAbsent() {
    #expect(parse("--show-continue-button").showsContinueButton)
    #expect(!parse().showsContinueButton)
  }

  @Test func theDiffCommandIsSplitOnCommas() {
    #expect(parse("--diff-cmd", "svn,diff,--internal-diff").diffCommand == ["svn", "diff", "--internal-diff"])
  }

  @Test func anOptionWithNoValueDoesNotConsumeTheNextFile() {
    // The old parser cancelled the window outright here. Dropping the option
    // leaves a usable window instead.
    let arguments = parse("one.txt", "--log")
    #expect(arguments.paths == ["one.txt"])
    #expect(arguments.log == "")
  }

  @Test func nothingToShowIsRecognizedRatherThanCrashed() {
    #expect(parse().isEmpty)
    #expect(parse("one.txt").isEmpty)
    #expect(!parse("--status", "M", "one.txt").isEmpty)
  }

  @Test func morePathsThanStatusesDropsTheExtraRatherThanCrashing() {
    // Indexing statuses by path position is what the old code did, and it
    // raised an exception when a caller passed more paths than statuses.
    let arguments = parse("--status", "M", "one.txt", "two.txt")
    #expect(arguments.items(didSelectFiles: false).count == 1)
  }
}

@Suite struct CommitActionTests {
  @Test func aDeclarationIsStatusesThenNameThenCommand() {
    let action = CommitAction(declaration: "A,M:Revert ${TM_DISPLAYNAME},svn,revert")
    #expect(action?.name == "Revert ${TM_DISPLAYNAME}")
    #expect(action?.command == ["svn", "revert"])
    #expect(action?.statuses == ["A", "M"])
  }

  @Test func itAppliesOnlyToTheStatusesItNames() {
    let action = CommitAction(declaration: "A,M:Revert,svn,revert")!
    #expect(action.applies(to: CommitItem(path: "a", status: "M", isIncluded: true)))
    #expect(!action.applies(to: CommitItem(path: "a", status: "D", isIncluded: true)))
  }

  @Test func aDeclarationWithNoColonIsNotAnAction() {
    #expect(CommitAction(declaration: "nonsense") == nil)
  }

  @Test func aDeclarationWithNoCommandIsNotAnAction() {
    #expect(CommitAction(declaration: "A:JustAName") == nil)
  }
}

@Suite struct CommitItemTests {
  @Test func ordinaryChangesStartChecked() {
    #expect(CommitItem.included(status: "M", didSelectFiles: false))
    #expect(CommitItem.included(status: "A", didSelectFiles: false))
    #expect(CommitItem.included(status: "D", didSelectFiles: false))
  }

  @Test func externalDefinitionsNeverDo() {
    #expect(!CommitItem.included(status: "X", didSelectFiles: false))
    #expect(!CommitItem.included(status: "X", didSelectFiles: true))
  }

  @Test func unversionedFilesOnlyWhenTheyWereNamed() {
    #expect(!CommitItem.included(status: "?", didSelectFiles: false))
    #expect(CommitItem.included(status: "?", didSelectFiles: true))
  }

  @Test func aPathIsStandardized() {
    #expect(CommitItem(path: "/tmp/./a/../b.txt", status: "M", isIncluded: true).path == "/tmp/b.txt")
  }
}

@Suite struct CommitStatusTests {
  @Test func aStatusStringIsOneColumnPerLetter() {
    #expect(CommitStatusColumn.columns(of: "MM").count == 2)
    #expect(CommitStatusColumn.columns(of: "A").count == 1)
  }

  @Test func anUnderscoreIsABlankColumn() {
    let columns = CommitStatusColumn.columns(of: "A_")
    #expect(!columns[0].isBlank)
    #expect(columns[1].isBlank)
  }

  @Test func aLetterNobodyKnowsStillGetsAColumn() {
    let columns = CommitStatusColumn.columns(of: "Z")
    #expect(columns.count == 1)
    #expect(columns[0].status == nil)
  }

  @Test func everyStatusHasBothColors() {
    for status in CommitStatus.allCases {
      #expect(status.foreground != status.background)
    }
  }
}

@Suite struct CommitOutputTests {
  @Test func theMessageIsQuotedForAShell() {
    let output = CommitWindowModel.standardOutput(message: "Fix it", paths: [])
    #expect(output.contains("-m 'Fix it'"))
  }

  @Test func anApostropheInTheMessageSurvives() {
    // A single quote cannot be escaped inside single quotes, so the quoting
    // has to close, escape and reopen. Getting this wrong truncates the
    // message at the apostrophe.
    let output = CommitWindowModel.standardOutput(message: "Don't", paths: [])
    #expect(output.contains(#"-m 'Don'"'"'t'"#))
  }

  @Test func everyIncludedPathFollowsTheMessage() {
    let output = CommitWindowModel.standardOutput(message: "m", paths: ["one.txt", "two.txt"])
    #expect(output.contains("one.txt"))
    #expect(output.contains("two.txt"))
  }

  @Test func aStatusIsTheFirstWordACommandWrites() {
    #expect(CommitWindowModel.statusFromCommandOutput("M some/file.txt\n") == "M")
    #expect(CommitWindowModel.statusFromCommandOutput("A\n") == "A")
  }

  @Test func outputWithNoWhitespaceIsNotAStatus() {
    #expect(CommitWindowModel.statusFromCommandOutput("garbage") == nil)
    #expect(CommitWindowModel.statusFromCommandOutput("") == nil)
  }
}

@Suite struct CommitMessageHistoryTests {
  private func history() -> (CommitMessageHistory, UserDefaults) {
    let name = "commit-window-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    return (CommitMessageHistory(defaults: defaults), defaults)
  }

  @Test func aMessageIsRemembered() {
    let (history, _) = history()
    history.remember("First")
    #expect(history.messages == ["First"])
  }

  @Test func aBlankMessageIsNot() {
    let (history, _) = history()
    history.remember("   \n ")
    #expect(history.messages.isEmpty)
  }

  @Test func theMenuReadsNewestFirst() {
    let (history, _) = history()
    history.remember("First")
    history.remember("Second")
    #expect(history.recent == ["Second", "First"])
  }

  @Test func repeatingAMessageMovesItRatherThanDuplicatingIt() {
    let (history, _) = history()
    history.remember("First")
    history.remember("Second")
    history.remember("First")
    #expect(history.messages == ["Second", "First"])
  }

  @Test func onlyTheLastFiveAreKept() {
    let (history, _) = history()
    for number in 1...7 { history.remember("Message \(number)") }
    #expect(history.messages.count == CommitMessageHistory.limit)
    #expect(history.messages.first == "Message 3")
  }

  @Test func clearingRemovesThemAll() {
    let (history, _) = history()
    history.remember("First")
    history.clear()
    #expect(history.messages.isEmpty)
  }

  @Test func aLongMessageIsShortenedForAMenu() {
    let title = CommitMessageHistory.title(of: String(repeating: "x", count: 50))
    #expect(title.count == CommitMessageHistory.titleLength + 1)
    #expect(title.hasSuffix("…"))
  }

  @Test func aMenuTitleIsTheFirstLineOnly() {
    #expect(CommitMessageHistory.title(of: "Summary\n\nThe body") == "Summary")
  }
}

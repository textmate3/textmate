import Testing

import Terminal

/// The stub emulator is the one piece here with an answer worth asserting on.
/// The pseudo terminal and the window are proven by running them, not by tests.
@Suite struct TerminalOutputStub {
  @Test func plainTextArrivesAsItIs() {
    var output = TerminalOutput()
    output.append("hello\n")
    #expect(output.text == "hello\n")
  }

  @Test func aControlSequenceIsDroppedRatherThanPrinted() {
    var output = TerminalOutput()
    output.append("\u{1B}[32mgreen\u{1B}[0m\n")
    #expect(output.text == "green\n")
  }

  @Test func anOperatingSystemCommandIsDropped() {
    var output = TerminalOutput()
    output.append("\u{1B}]0;a window title\u{07}prompt$ ")
    #expect(output.text == "prompt$ ")
  }

  @Test func carriageReturnGoesBackToTheStartOfTheLine() {
    var output = TerminalOutput()
    output.append("first line\nrewrite me\rdone")
    #expect(output.text == "first line\ndone")
  }

  @Test func backspaceRemovesOneCharacterButNotTheNewline() {
    var output = TerminalOutput()
    output.append("ab\u{08}")
    #expect(output.text == "a")

    var atLineStart = TerminalOutput()
    atLineStart.append("a\n\u{08}")
    #expect(atLineStart.text == "a\n")
  }

  @Test func theBellMakesNoMark() {
    var output = TerminalOutput()
    output.append("ding\u{07}")
    #expect(output.text == "ding")
  }

  @Test func trimmingKeepsTheLastLines() {
    var output = TerminalOutput()
    output.append("one\ntwo\nthree\nfour\n")
    output.trim(toLastLines: 2)
    #expect(output.text == "four\n")
  }

  @Test func trimmingLeavesShortOutputAlone() {
    var output = TerminalOutput()
    output.append("one\ntwo\n")
    output.trim(toLastLines: 10)
    #expect(output.text == "one\ntwo\n")
  }
}

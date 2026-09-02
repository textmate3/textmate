# `.tm_properties`

Settings and environment variables for the editor, per folder, per file type and per file. TextMate reads them from a chain of `.tm_properties` files and from the defaults it ships with.

## Where settings come from

Settings are read in this order. A later file wins over an earlier one.

1. `Default.tmProperties` inside the application bundle, at `Contents/Resources/Default.tmProperties`.
2. `~/.tm_properties`, the global file.
3. `.tm_properties` in every folder from the top down to the folder holding the file. For a file under the home folder the chain starts at the home folder. For a file elsewhere it starts at `/`.
4. Environment variables from Preferences → Variables are available to values in all of the above.

So a `.tm_properties` at the root of a project overrides the global file, and one in a subfolder overrides the project's.

Values a user changes through the menus, such as View → Soft Wrap, are stored in the application defaults and win over every file above.

## Syntax

One assignment per line. `#` starts a comment. Blank lines are ignored.

```
tabSize  = 2
softTabs = true
encoding = "UTF-8"
windowTitle = '$TM_DISPLAYNAME'
```

A value is a bare word, a single quoted string or a double quoted string. Both quoting styles behave the same. Inside quotes a backslash escapes the quote character and another backslash. Booleans are `true` and `false`. Numbers are written as digits.

A line that is not a comment, an assignment or a section header is reported as a syntax error in the system log and skipped.

### Sections

A section header restricts the assignments that follow it, up to the next header. A header is either a scope selector or a glob.

```
[ source.ruby ]
softTabs = true
tabSize  = 2

[ *.go ]
relatedFilePath = "${TM_FILEPATH/(_test)?(?=\.go$)/${1:?:_test}/}"

[ "/System/Library/Frameworks/**/Headers/**" ]
encoding = "MACROMAN"
tabSize  = 8
```

A header is a scope selector when it starts with `text`, `source` or `attr`. Anything else is a glob matched against the full path of the file. Quote a glob when it contains spaces or braces. Several headers can share one section, separated by `;`.

Assignments before the first header apply to every file.

### Variables

Any key that is not one of the settings below is an environment variable. It is exported to commands, snippets and the shell TextMate runs, and it can be referenced by the values that follow it, even inside the same file.

```
TM_ORGANIZATION_NAME = 'MacroMates'
exclude              = '{$exclude,*.o}'
```

Values expand `$NAME` and `${NAME}`. They also support the format string operators:

| Form                          | Meaning                                                   |
| ----------------------------- | --------------------------------------------------------- |
| `${NAME:-default}`            | `default` when `NAME` is unset                            |
| `${NAME:+text}`               | `text` when `NAME` is set, nothing otherwise              |
| `${NAME:?yes:no}`             | `yes` when `NAME` is set, `no` otherwise                  |
| `${NAME/regexp/replacement/}` | `NAME` with the first match of `regexp` replaced          |

`$CWD` is the folder that holds the `.tm_properties` file being read. Use it for anything that must refer to the project root rather than the current file, such as `projectDirectory = "$CWD"`.

The shipped defaults define `TM_APP_PATH`, `TM_MATE`, `TM_QUERY` and `TM_SCM_COMMIT_WINDOW` this way, and build `windowTitle` out of two helper variables, `windowTitleProject` and `windowTitleSCM`.

## Settings

### Editing

| Key                | Type    | Meaning                                                                                        |
| ------------------ | ------- | ---------------------------------------------------------------------------------------------- |
| `fileType`         | scope   | The grammar to use, as its root scope, such as `text.plain` or `source.ruby`.                 |
| `scopeAttributes`  | string  | Extra scopes appended to the file's scope, so bundle items can target it, such as `attr.test`. |
| `softTabs`         | boolean | Insert spaces when Tab is pressed.                                                             |
| `tabSize`          | integer | Width of a tab in characters.                                                                  |
| `softWrap`         | boolean | Wrap long lines.                                                                               |
| `wrapColumn`       | integer | Column to wrap at. Without it lines wrap at the window edge.                                   |
| `spellChecking`    | boolean | Check spelling as you type.                                                                    |
| `spellingLanguage` | string  | Dictionary to check with, such as `en` or `de`. The Edit → Spelling menu lists what is installed. |
| `relatedFilePath`  | path    | Where Navigate → Go to Related File goes, usually a format string over `TM_FILEPATH`.         |

### Display

| Key                | Type    | Meaning                                                                                                 |
| ------------------ | ------- | ------------------------------------------------------------------------------------------------------- |
| `theme`            | UUID    | The theme to use, by the UUID in its `.tmTheme` file.                                                   |
| `fontName`         | string  | The font, by PostScript name.                                                                           |
| `fontSize`         | number  | The font size in points.                                                                                |
| `showInvisibles`   | boolean | Draw glyphs for spaces, tabs and newlines.                                                              |
| `invisiblesMap`    | string  | Which glyph to draw for each invisible. See below.                                                      |
| `showWrapColumn`   | boolean | Draw a line at the wrap column.                                                                         |
| `showIndentGuides` | boolean | Draw a line at each indentation level.                                                                  |
| `windowTitle`      | string  | Format string for the window title. The default shows the file name, the project folder and the branch. |
| `tabTitle`         | string  | Format string for the tab title. The default is the file name.                                          |

`invisiblesMap` is a sequence of pairs. Each pair is one of the three invisible characters, a space, a tab or a newline, followed by the glyph to draw for it. A `~` before the character draws nothing for it. Written in a double quoted string:

```
invisiblesMap = "~ \t→\n¬"
```

This hides spaces, draws a tab as `→` and a newline as `¬`.

### Files

| Key                         | Type    | Meaning                                                                                                        |
| --------------------------- | ------- | -------------------------------------------------------------------------------------------------------------- |
| `encoding`                  | string  | Encoding to save with, and to fall back on when a file is not UTF-8. An `iconv` name, such as `CP1252`.        |
| `lineEndings`               | string  | Line endings to save with, `"\n"` or `"\r\n"`.                                                                 |
| `atomicSave`                | string  | When to save through a temporary file. See below.                                                              |
| `disableExtendedAttributes` | boolean | Do not store caret position, folds and the like in the file's extended attributes.                             |
| `saveOnBlur`                | boolean | Save the file when the window loses focus.                                                                     |
| `binary`                    | boolean | Treat the file as binary. The file browser opens it with its own application rather than in TextMate.          |
| `projectDirectory`          | path    | The project root, which sets `TM_PROJECT_DIRECTORY` and the default folder for Find in Project.                |
| `storeEncodingPerFile`      | boolean | Reserved. Read by nothing today.                                                                               |

`atomicSave` chooses when a save goes through a new file that replaces the old one, which keeps a crash from leaving a half written file but breaks hard links and changes the file's inode.

| Value             | Meaning                                                           |
| ----------------- | ----------------------------------------------------------------- |
| `always`          | The default. Every save goes through a new file.                  |
| `externalVolumes` | Only on volumes other than the startup disk.                      |
| `remoteVolumes`   | Only on network volumes.                                          |
| `never`           | Write in place.                                                   |
| `legacy`          | Swap the file contents when the file system allows it, otherwise as `always`. |

### Source control

| Key                 | Type    | Meaning                                                                                             |
| ------------------- | ------- | --------------------------------------------------------------------------------------------------- |
| `scmStatus`         | string  | When to show source control badges and set the `TM_SCM_*` variables. See below.                     |
| `excludeSCMDeleted` | boolean | Hide files that are tracked by source control but no longer on disk from the file browser.          |

| Value                | Meaning                                                    |
| -------------------- | ---------------------------------------------------------- |
| `enableIfLocalDisk`  | The default. On for local volumes, off for network mounts. |
| `enableIfSystemDisk` | On only for the startup disk.                              |
| `enable`             | Always on.                                                 |
| `disable`            | Always off.                                                |

Source control is never used for `/` or the home folder itself, whatever the setting.

### Which files are shown

These keys are globs. They decide what the file browser, the Go to File window and Find in Project list. The default `include` is `*`, so hidden files stay out unless a more specific key lets them in. The shipped defaults add `.tm_properties` and `.htaccess`.

For a file, the first of these keys that has a value is the exclude test, in this order: the one for the place, then the one for files, then the general one. If the file does not match it, the include keys are tested the same way, and the file is shown when it matches. Folders use the `Directories` keys in the same way.

| Place              | Exclude keys                                                                   | Include keys                                                                   |
| ------------------ | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| Everywhere         | `exclude`, `excludeFiles`, `excludeDirectories`                                | `include`, `includeFiles`, `includeDirectories`                                |
| File browser       | `excludeInBrowser`, `excludeFilesInBrowser`, `excludeDirectoriesInBrowser`     | `includeInBrowser`, `includeFilesInBrowser`, `includeDirectoriesInBrowser`     |
| Go to File         | `excludeInFileChooser`, `excludeFilesInFileChooser`, `excludeDirectoriesInFileChooser` | `includeInFileChooser`, `includeFilesInFileChooser`                    |
| Find in Project    | `excludeInFolderSearch`, `excludeFilesInFolderSearch`, `excludeDirectoriesInFolderSearch` |                                                                     |

To extend a default rather than replace it, reference it:

```
excludeInFileChooser = "{$exclude,*.xib}"
```

`followSymbolicLinks`, a boolean, makes Go to File descend into folders reached through symbolic links.

## The shipped defaults

`Default.tmProperties` in the application bundle is the file every other setting builds on. It sets the font size and encoding, the default include and exclude globs, the list of binary extensions, the window title, and per language tab settings for Ruby, Python, Makefiles and Ninja files. Read it for a worked example of every construct above.

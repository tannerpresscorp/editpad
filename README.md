# EditPad

A lightweight plain-text and code editor for iPhone and iPad.

EditPad opens any text file from the Files app (notes, Markdown, source code, JSON, YAML, config files, logs, dotfiles) and saves it back exactly as it found it: same encoding, same byte order mark, same line endings.

## Features

**Works with the Files app**
- Built on SwiftUI `DocumentGroup`: browse, create, rename and move files in iCloud Drive, On My iPhone, or any Files provider, and edit them in place.
- EditPad appears under *Open with* / *Share* for text and code files. Files with unusual or missing extensions (`LICENSE`, `.gitignore`, `Dockerfile`, `.ts`) open from the in-app browser too; binary files are politely refused.
- Files you create live in **On My iPhone › EditPad**.
- **Share** the current file and **Show in Files** from the toolbar.

**Made for code**
- Syntax highlighting for about 30 languages: Swift, Objective-C, C, C++, C#, Java, Kotlin, Scala, Dart, Go, Rust, JavaScript, TypeScript, Python, Ruby, PHP, Lua, Perl, Shell, PowerShell, SQL, HTML, XML, CSS/SCSS, JSON, YAML, TOML, INI/config, Markdown, Makefile and Dockerfile. Detected from the file name or a `#!` shebang, with a manual override.
- Spell checking, autocorrect, smart quotes, smart dashes and predictive text are **off by default**, each switchable in Settings.
- Auto-indent (keeps the line's indentation and indents after `{`, `[`, `(`, or `:` in Python and YAML) and a configurable Tab key (tab, 2 or 4 spaces).
- A coding keyboard bar with brackets, operators, Tab, undo, redo and hide-keyboard.
- Find and replace (Cmd-F, or the toolbar button).

**Faithful saving**
- UTF-8, UTF-16 LE/BE, Windows-1252 and ISO Latin 1, with or without a BOM; LF, CRLF or CR line endings are detected on open and restored on save.
- Change a file's line endings or encoding from the options menu. If the text can't be stored in the chosen encoding, the status bar warns and EditPad saves as UTF-8 instead of losing characters.
- Status bar with word, character and line counts, language, line endings and encoding.

## Requirements

- Xcode 16 or later
- iOS / iPadOS 17 or later

## Getting started

```sh
git clone https://github.com/tannerpresscorp/editpad.git
cd editpad
open EditPad.xcodeproj
```

Choose the **EditPad** scheme and a simulator, then run. To install on a device, select your team under *Signing & Capabilities*.

## Project layout

```
EditPad.xcodeproj             Xcode project (folder-synchronized; new files in EditPad/ are picked up automatically)
EditPad/                      SwiftUI app
  CodeTextView.swift          UITextView editor: highlighting, input traits, auto-indent, keyboard bar
  EditorView.swift            Toolbar, menus, Share and Show in Files
  SupportedFileTypes.swift    Generated list of openable file types
Config/Info.plist             Document types and imported type declarations (generated sections)
Packages/EditPadKit/          Platform-independent core: codec, line endings, statistics, syntax tokenizer, indentation
scripts/generate-file-types.py  Regenerates the file-type declarations in Info.plist and Swift
.github/workflows/ci.yml      Core tests on Linux and macOS, plus an iOS Simulator build
```

All file-format and syntax logic lives in `EditPadKit` so it can be unit tested without a simulator:

```sh
swift test --package-path Packages/EditPadKit
```

To support a new file extension, add it to `SyntaxLanguage.byExtension` (for highlighting) and to the tables in `scripts/generate-file-types.py` (for the Files app), then run `python3 scripts/generate-file-types.py`.

## License

MIT. See [LICENSE](LICENSE).

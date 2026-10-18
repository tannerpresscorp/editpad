# EditPad

A lightweight plain-text editor for iPhone and iPad.

EditPad opens any plain-text file from the Files app (notes, Markdown, code, JSON, YAML, CSV, logs) and saves it back exactly as it found it: same encoding, same byte order mark, same line endings.

## Features

- **Document browser** built on SwiftUI `DocumentGroup`: create, open, rename and move files in iCloud Drive, On My iPhone, or any Files provider.
- **Find and replace** using the system find navigator (Cmd-F on a hardware keyboard).
- **Faithful saving**: UTF-8, UTF-16 LE/BE, Windows-1252 and ISO Latin 1, with or without a BOM; LF, CRLF or CR line endings are detected on open and restored on save.
- **Format controls**: change a file's line endings or encoding from the options menu.
- **Status bar** with word, character and line counts plus the file's encoding and line endings. A warning icon appears if the text can't be saved in the chosen encoding (EditPad then saves as UTF-8 rather than losing characters).
- **Editor settings**: font size (Cmd-= / Cmd-−), monospaced or proportional font, optional autocorrect, status bar on or off.

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
EditPad.xcodeproj         Xcode project (folder-synchronized; new files in EditPad/ are picked up automatically)
EditPad/                  SwiftUI app: document model, editor, status bar, settings, assets
Config/Info.plist         Document types, Markdown type declaration, Files app integration
Packages/EditPadKit/      Platform-independent core: encoding and line-ending codec, text statistics
.github/workflows/ci.yml  Core tests on Linux and macOS, plus an iOS Simulator build
```

All file-format logic lives in `EditPadKit` so it can be unit tested without a simulator:

```sh
swift test --package-path Packages/EditPadKit
```

## License

MIT. See [LICENSE](LICENSE).

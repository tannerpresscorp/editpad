# EditPad

Lightweight plain-text editor for iOS and iPadOS 17+, built with SwiftUI. Opens any text file from the Files app and saves it back with its original encoding, BOM and line endings.

## Layout

- `EditPad/` — SwiftUI app target (folder-synchronized: new files are added to the target automatically)
  - `EditPadApp.swift` — `DocumentGroup` scene
  - `TextDocument.swift` — `FileDocument` adapter over `EditPadKit`
  - `EditorView.swift`, `StatusBar.swift`, `SettingsView.swift`, `EditorSettings.swift`
- `Config/Info.plist` — document types and the Markdown type declaration (merged with generated Info.plist keys)
- `Packages/EditPadKit/` — Foundation-only core: `TextCodec`, `LineEnding`, `TextEncoding`, `SingleByteCodec`, `TextStatistics`
- `.github/workflows/ci.yml` — Linux and macOS package tests, iOS Simulator build

## Commands

```sh
# Core tests (works on Linux and macOS)
swift test --package-path Packages/EditPadKit

# App build (macOS with Xcode 16+)
xcodebuild build -project EditPad.xcodeproj -scheme EditPad \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO

# Agent config check
bash scripts/verify-agents.sh
```

Without a Mac, push a branch and read the iOS build result from GitHub Actions (`gh run list --repo tannerpresscorp/editpad`).

## Rules

- Keep the app lightweight: no third-party dependencies unless a human asks.
- All decoding, encoding and line-ending logic belongs in `EditPadKit`, never in views.
- Unedited files must save byte-for-byte identical. Add a case to `testRoundTripPreservesBytes` for any new encoding or line-ending path; never weaken it.
- Don't use `String.Encoding.windowsCP1252` or `.isoLatin1`: Linux Foundation decodes them differently. Use `SingleByteCodec`.
- Don't hand-edit file references in `EditPad.xcodeproj/project.pbxproj`; synchronized folders handle them.
- Don't change the bundle identifier, signing or team settings.
- Record architecture decisions in `DECISIONS.md`.

## Agent Context

> AGENTS.md is the source of truth. Start every session by reading it.

| Agent | Owns | Handoff trigger |
|-------|------|----------------|
| coordinator | routing, planning, `AGENTS.md` | work spans app and core, or ownership is unclear |
| core | `Packages/EditPadKit/Sources/` | decoding, encoding, BOM, line endings, statistics |
| app | `EditPad/`, `Config/`, `EditPad.xcodeproj/` | UI, settings, document types, build settings |
| test-writer | `Packages/EditPadKit/Tests/` | new or missing test coverage |
| navigator | read-only | "where is…" or "how does…" questions |

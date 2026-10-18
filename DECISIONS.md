# Decisions

Architecture decisions for EditPad, newest first. Each entry: what was decided, why, and what it rules out.

## 2026-10-18 — Single-byte encodings use hand-written tables

**Decision:** Windows-1252 and ISO Latin 1 are decoded and encoded by `SingleByteCodec`, not `String.Encoding`.
**Why:** Foundation on Linux rejects bytes 0x80–0x9F for these encodings while Apple platforms accept them, so tests passed or failed depending on where they ran.
**Consequence:** Behavior is identical on device, simulator and Linux CI. Adding another single-byte encoding means adding a table.

## 2026-10-18 — Normalize to LF in memory, restore on save

**Decision:** Text is `\n`-normalized on open. The detected line ending (dominant style; ties go to LF), encoding and BOM are kept in `TextFormat` and re-applied on save.
**Why:** `TextEditor` inserts `\n`; mixing it with CRLF files produced inconsistent endings. Normalizing keeps editing simple and saving faithful.
**Consequence:** Files with mixed line endings are saved with a single, dominant style.

## 2026-10-18 — Fall back to UTF-8 rather than lose characters

**Decision:** If the text can't be represented in the file's encoding, save as UTF-8. The status bar warns before this happens.
**Why:** Silent data loss is worse than an encoding change.

## 2026-10-18 — File-format logic in a local Swift package

**Decision:** `EditPadKit` (Foundation only) holds the codec and statistics; the app target only adapts it to SwiftUI.
**Why:** The riskiest code (byte handling) can be unit tested with `swift test` anywhere, including Linux, without a simulator.

## 2026-10-18 — SwiftUI DocumentGroup, iOS 17, no dependencies

**Decision:** Use `DocumentGroup` + `FileDocument` + `TextEditor` with the system find navigator. Minimum iOS 17. No third-party packages.
**Why:** The system document browser gives Files integration, autosave, rename and iCloud for free, which is the "lightweight" goal.
**Rules out (for now):** syntax highlighting, line numbers and cursor position, which need a custom `UITextView` wrapper.

## 2026-10-18 — Xcode 16 folder-synchronized project

**Decision:** `EditPad.xcodeproj` uses synchronized folders (objectVersion 77); `Info.plist` lives in `Config/` outside the synchronized folder.
**Why:** New source files need no project-file edits, which keeps diffs small and avoids merge conflicts. Requires Xcode 16+.

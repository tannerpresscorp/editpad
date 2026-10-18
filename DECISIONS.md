# Decisions

Architecture decisions for EditPad, newest first. Each entry: what was decided, why, and what it rules out.

## 2026-10-18 — UITextView instead of SwiftUI TextEditor

**Decision:** The editor is `CodeTextView`, a `UIViewRepresentable` around `UITextView`.
**Why:** `TextEditor` has no way to turn off spell checking, smart quotes, smart dashes or inline predictions, and can't apply per-range colors. All of these matter for editing code.
**Supersedes:** "Rules out syntax highlighting" in the DocumentGroup entry below.

## 2026-10-18 — Regex tokenizer, not a parser

**Decision:** Highlighting uses per-language regular expressions in `EditPadKit` (`SyntaxGrammar`, `SyntaxHighlighter`): comments and strings first in one alternation, then keywords, types, calls and numbers outside them. Tokenizing runs on a background queue; files over 250 KB aren't highlighted.
**Why:** Keeps the app dependency-free and lightweight while covering ~30 languages. Measured ~85 ms for a 227 KB Swift file on Linux release builds.
**Consequence:** Highlighting is approximate (no regex literals, no nested template expressions). Tree-sitter would be the next step if accuracy becomes a priority.

## 2026-10-18 — Open any file, refuse binaries at decode time

**Decision:** `public.data` is a readable type with `LSHandlerRank` None, alongside ~45 text and code types at rank Alternate. Code types iOS doesn't declare are imported in Info.plist. Both lists are generated from `scripts/generate-file-types.py`.
**Why:** Dotfiles, `LICENSE`, `Dockerfile` and `.ts` (which iOS types as MPEG transport stream) otherwise can't be opened. Rank None keeps EditPad out of "Open with" for images and other binaries; `TextCodec` rejects binary data with a clear error.

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
**Rules out (for now):** syntax highlighting, line numbers and cursor position, which need a custom `UITextView` wrapper. (Highlighting since added; see above.)

## 2026-10-18 — Xcode 16 folder-synchronized project

**Decision:** `EditPad.xcodeproj` uses synchronized folders (objectVersion 77); `Info.plist` lives in `Config/` outside the synchronized folder.
**Why:** New source files need no project-file edits, which keeps diffs small and avoids merge conflicts. Requires Xcode 16+.

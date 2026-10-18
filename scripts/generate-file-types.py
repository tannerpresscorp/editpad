#!/usr/bin/env python3
"""Generate EditPad's file-type declarations from one table.

Writes:
  Config/Info.plist                 CFBundleDocumentTypes + UTImportedTypeDeclarations
  EditPad/SupportedFileTypes.swift  the matching UTType list for TextDocument

Run from the repo root after editing the tables below:
  python3 scripts/generate-file-types.py
"""
import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# System-declared types: (UTType identifier, Swift constant).
BUILT_IN = [
    ("public.plain-text", ".plainText"),
    ("public.utf8-plain-text", ".utf8PlainText"),
    ("public.utf16-plain-text", ".utf16PlainText"),
    ("public.source-code", ".sourceCode"),
    ("public.script", ".script"),
    ("public.swift-source", ".swiftSource"),
    ("public.c-source", ".cSource"),
    ("public.c-header", ".cHeader"),
    ("public.c-plus-plus-source", ".cPlusPlusSource"),
    ("public.c-plus-plus-header", ".cPlusPlusHeader"),
    ("public.objective-c-source", ".objectiveCSource"),
    ("public.objective-c-plus-plus-source", ".objectiveCPlusPlusSource"),
    ("public.assembly-source", ".assemblyLanguageSource"),
    ("public.python-script", ".pythonScript"),
    ("public.ruby-script", ".rubyScript"),
    ("public.perl-script", ".perlScript"),
    ("public.php-script", ".phpScript"),
    ("public.shell-script", ".shellScript"),
    ("com.netscape.javascript-source", ".javaScript"),
    ("public.json", ".json"),
    ("public.xml", ".xml"),
    ("public.yaml", ".yaml"),
    ("public.html", ".html"),
    ("public.comma-separated-values-text", ".commaSeparatedText"),
    ("public.tab-separated-values-text", ".tabSeparatedText"),
    ("public.log", ".log"),
    ("com.apple.property-list", ".propertyList"),
    ("public.make-source", ".makefile"),
]

# Types iOS doesn't declare: (identifier, description, conforms to, extensions, MIME types).
NS = "com.tannerpresscorp.editpad.source."
IMPORTED = [
    ("net.daringfireball.markdown", "Markdown Document", "public.plain-text", ["md", "markdown", "mdown", "mkd"], ["text/markdown"]),
    ("com.microsoft.typescript", "TypeScript Source", "public.source-code", ["ts", "mts", "cts"], ["text/typescript"]),
    (NS + "jsx", "JSX Source", "public.source-code", ["jsx", "tsx"], []),
    (NS + "css", "Style Sheet", "public.source-code", ["css", "scss", "sass", "less"], ["text/css"]),
    (NS + "go", "Go Source", "public.source-code", ["go"], []),
    (NS + "rust", "Rust Source", "public.source-code", ["rs"], []),
    (NS + "kotlin", "Kotlin Source", "public.source-code", ["kt", "kts"], []),
    (NS + "java", "Java Source", "public.source-code", ["java", "groovy", "gradle"], []),
    (NS + "csharp", "C# Source", "public.source-code", ["cs", "csx"], []),
    (NS + "dart", "Dart Source", "public.source-code", ["dart"], []),
    (NS + "scala", "Scala Source", "public.source-code", ["scala", "sc"], []),
    (NS + "lua", "Lua Source", "public.source-code", ["lua"], []),
    (NS + "sql", "SQL Script", "public.source-code", ["sql"], ["application/sql"]),
    (NS + "powershell", "PowerShell Script", "public.source-code", ["ps1", "psm1", "psd1"], []),
    (NS + "shell", "Shell Script", "public.shell-script", ["bash", "zsh", "fish", "ksh"], []),
    (NS + "component", "Web Component", "public.source-code", ["vue", "svelte"], []),
    (NS + "toml", "TOML Document", "public.plain-text", ["toml"], ["application/toml"]),
    (NS + "config", "Configuration File", "public.plain-text",
     ["ini", "cfg", "conf", "properties", "env", "editorconfig", "gitignore", "gitattributes", "npmrc"], []),
    (NS + "dockerfile", "Dockerfile", "public.plain-text", ["dockerfile"], []),
]


def swift_identifier(identifier):
    name = identifier.rsplit(".", 1)[-1]
    if identifier == "net.daringfireball.markdown":
        return "markdown"
    if identifier == "com.microsoft.typescript":
        return "typeScript"
    return "editPad" + name[0].upper() + name[1:]


def write_plist():
    path = ROOT / "Config" / "Info.plist"
    with path.open("rb") as f:
        plist = plistlib.load(f)

    text_types = [identifier for identifier, _ in BUILT_IN] + [row[0] for row in IMPORTED]
    plist["CFBundleDocumentTypes"] = [
        {
            "CFBundleTypeName": "Text and Source Code",
            "CFBundleTypeRole": "Editor",
            "LSHandlerRank": "Alternate",
            "LSItemContentTypes": text_types,
        },
        {
            # Lets the in-app browser open files with unknown or missing
            # extensions (LICENSE, .gitignore, .ts). Rank None keeps EditPad
            # out of "Open with" for images and other binaries.
            "CFBundleTypeName": "Any File",
            "CFBundleTypeRole": "Viewer",
            "LSHandlerRank": "None",
            "LSItemContentTypes": ["public.data"],
        },
    ]
    imported = []
    for identifier, description, conforms, extensions, mimes in IMPORTED:
        tags = {"public.filename-extension": extensions}
        if mimes:
            tags["public.mime-type"] = mimes
        imported.append({
            "UTTypeConformsTo": [conforms],
            "UTTypeDescription": description,
            "UTTypeIdentifier": identifier,
            "UTTypeTagSpecification": tags,
        })
    plist["UTImportedTypeDeclarations"] = imported
    with path.open("wb") as f:
        plistlib.dump(plist, f, sort_keys=True)


def write_swift():
    lines = [
        "// Generated by scripts/generate-file-types.py. Do not edit by hand.",
        "import UniformTypeIdentifiers",
        "",
        "extension UTType {",
    ]
    for identifier, _, conforms, _, _ in IMPORTED:
        base = {"public.plain-text": ".plainText", "public.source-code": ".sourceCode",
                "public.shell-script": ".shellScript"}[conforms]
        lines.append(f'    static let {swift_identifier(identifier)} = UTType(importedAs: "{identifier}", conformingTo: {base})')
    lines += ["}", "", "enum SupportedFileTypes {",
              "    /// Every type EditPad opens, most specific first. `.data` is the catch-all",
              "    /// for files with unknown or missing extensions; binary files are rejected",
              "    /// when decoding.",
              "    static let readable: [UTType] = ["]
    for _, constant in BUILT_IN:
        lines.append(f"        {constant},")
    for row in IMPORTED:
        lines.append(f"        .{swift_identifier(row[0])},")
    lines += ["        .data,", "    ]", "}", ""]
    (ROOT / "EditPad" / "SupportedFileTypes.swift").write_text("\n".join(lines))


if __name__ == "__main__":
    write_plist()
    write_swift()
    print(f"{len(BUILT_IN)} built-in and {len(IMPORTED)} imported types written.")

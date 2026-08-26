#!/usr/bin/env python3
"""Discover and import shortcut files from common developer tools.

The importer is deliberately read-only. It never starts an editor or sources a
user configuration: doing so would make opening the cheatsheet slow and could
run arbitrary plugin code. VS Code JSONC and JetBrains XML are deterministic;
Neovim Lua is reported as a partial static import because mappings may be
created dynamically at runtime.
"""

from __future__ import annotations

import glob
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any, Iterable


COMMAND_NAMES = {
    "workbench.action.showCommands": "Show command palette",
    "workbench.action.quickOpen": "Quick open file",
    "workbench.view.explorer": "Focus Explorer",
    "workbench.action.findInFiles": "Search across files",
    "workbench.action.terminal.toggleTerminal": "Toggle integrated terminal",
    "editor.action.revealDefinition": "Go to definition",
    "editor.action.rename": "Rename symbol",
    "editor.action.quickFix": "Show quick fixes",
    "editor.action.formatDocument": "Format document",
}

JETBRAINS_NAMES = {
    "GotoAction": "Find action",
    "SearchEverywhere": "Search everywhere",
    "GotoClass": "Go to class",
    "GotoFile": "Go to file",
    "GotoSymbol": "Go to symbol",
    "GotoDeclaration": "Go to declaration",
    "FindUsages": "Find usages",
    "RenameElement": "Rename",
    "ReformatCode": "Reformat code",
    "OptimizeImports": "Optimize imports",
}


def emit(payload: dict[str, Any], status: int = 0) -> None:
    print(json.dumps(payload, ensure_ascii=False))
    raise SystemExit(status)


def _remove_trailing_commas(text: str) -> str:
    """Remove commas before ]/} while leaving comma-like string data intact."""
    output: list[str] = []
    in_string = False
    quote = ""
    escaped = False
    for index, char in enumerate(text):
        if in_string:
            output.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                in_string = False
            continue
        if char in {'"', "'"}:
            in_string = True
            quote = char
            output.append(char)
            continue
        if char == ",":
            lookahead = index + 1
            while lookahead < len(text) and text[lookahead].isspace():
                lookahead += 1
            if lookahead < len(text) and text[lookahead] in "]}":
                continue
        output.append(char)
    return "".join(output)


def strip_jsonc(text: str) -> str:
    """Remove JS comments and trailing commas without changing string data."""
    output: list[str] = []
    index = 0
    in_string = False
    quote = ""
    escaped = False
    while index < len(text):
        char = text[index]
        nxt = text[index + 1] if index + 1 < len(text) else ""
        if in_string:
            output.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                in_string = False
            index += 1
            continue
        if char in {'"', "'"}:
            in_string = True
            quote = char
            output.append(char)
            index += 1
            continue
        if char == "/" and nxt == "/":
            index += 2
            while index < len(text) and text[index] not in "\r\n":
                index += 1
            continue
        if char == "/" and nxt == "*":
            index += 2
            while index + 1 < len(text) and text[index : index + 2] != "*/":
                index += 1
            index += 2
            continue
        output.append(char)
        index += 1
    return _remove_trailing_commas("".join(output))


def humanize(identifier: str) -> str:
    value = identifier.strip().lstrip("-")
    if not value:
        return "Shortcut"
    value = value.split(".")[-1].replace("_", " ").replace("-", " ")
    value = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", value)
    value = re.sub(r"\s+", " ", value).strip()
    return value[:1].upper() + value[1:]


def page(name: str, icon: str, program: str, source_kind: str, source_path: Path,
         keybinds: list[dict[str, str]], note: str = "") -> dict[str, Any]:
    return {
        "name": name,
        "icon": icon,
        "program": program,
        "sourceKind": source_kind,
        "sourcePath": str(source_path),
        "importNote": note,
        "keybinds": keybinds,
    }


def import_vscode(path: Path) -> dict[str, Any]:
    if path.stat().st_size > 5 * 1024 * 1024:
        raise ValueError("VS Code keybindings file is unexpectedly large")
    data = json.loads(strip_jsonc(path.read_text(encoding="utf-8")))
    if not isinstance(data, list):
        raise ValueError("VS Code keybindings.json must contain an array")
    keybinds: list[dict[str, str]] = []
    for item in data:
        if not isinstance(item, dict):
            continue
        keys = str(item.get("key", "")).strip()
        command = str(item.get("command", "")).strip()
        if not keys or not command or command.startswith("-"):
            continue
        keybinds.append({
            "keys": keys,
            "description": COMMAND_NAMES.get(command, humanize(command)),
            "category": "Custom",
            "context": str(item.get("when", "")).strip(),
            "notes": command,
        })
    parent_name = path.parent.parent.name.lower()
    if "cursor" in parent_name:
        app_name = "Cursor"
    elif "vscodium" in parent_name:
        app_name = "VSCodium"
    else:
        app_name = "Visual Studio Code"
    return page(app_name, "code", app_name, "vscode", path, keybinds,
                "Imported from the editor user keybindings file.")


def lua_string(value: str) -> str:
    # Decode the common Lua string escapes without round-tripping UTF-8 bytes
    # through unicode_escape, which would mojibake non-ASCII descriptions.
    return (
        value.replace(r"\n", "\n")
        .replace(r"\t", "\t")
        .replace(r'\"', '"')
        .replace(r"\'", "'")
        .replace(r"\\", "\\")
    )


def neovim_lua_keybinds(text: str, file_name: str) -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    starts = list(re.finditer(r"(?:vim\.)?keymap\.set\s*\(", text))
    for position, match in enumerate(starts):
        end = starts[position + 1].start() if position + 1 < len(starts) else min(len(text), match.start() + 1800)
        block = text[match.end() : end]
        mode_match = re.match(r"\s*(?P<mode>\{[^}]*\}|(['\"])(?P<single>.*?)\2)\s*,", block, re.S)
        if not mode_match:
            continue
        rest = block[mode_match.end() :]
        lhs_match = re.match(r"\s*(['\"])(?P<lhs>(?:\\.|(?!\1).)*)\1\s*,", rest, re.S)
        if not lhs_match:
            continue
        lhs = lua_string(lhs_match.group("lhs")).strip()
        if not lhs:
            continue
        single_mode = mode_match.group("single")
        modes = [single_mode] if single_mode is not None else re.findall(
            r"['\"]([^'\"]+)['\"]", mode_match.group("mode") or ""
        )
        desc_match = re.search(r"\bdesc\s*=\s*(['\"])(?P<desc>(?:\\.|(?!\1).)*)\1", rest[:1200], re.S)
        description = lua_string(desc_match.group("desc")).strip() if desc_match else "Custom mapping"
        entries.append({
            "keys": lhs,
            "description": description,
            "category": "Custom mappings",
            "context": ", ".join(modes) + (" mode" if modes else ""),
            "notes": file_name,
        })
    return entries


VIM_MAP_RE = re.compile(
    r"^\s*(?P<command>(?:[nvisxoctl]?noremap|[nvisxoctl]?map)!?)\s+"
    r"(?:(?:<silent>|<expr>|<buffer>|<nowait>)\s+)*(?P<lhs>\S+)\s+(?P<rhs>.+?)\s*$",
    re.I,
)


def neovim_vimscript_keybinds(text: str, file_name: str) -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    for line in text.splitlines():
        match = VIM_MAP_RE.match(line)
        if not match:
            continue
        command = match.group("command").lower()
        mode = command[0] if command[0] in "nvisxoctl" else ""
        entries.append({
            "keys": match.group("lhs"),
            "description": "Run " + match.group("rhs")[:180],
            "category": "Custom mappings",
            "context": (mode + " mode") if mode else "",
            "notes": file_name,
        })
    return entries


def iter_neovim_files(root: Path) -> Iterable[Path]:
    emitted = 0
    scanned_bytes = 0
    for path in sorted(root.rglob("*")):
        if any(part in {".git", "node_modules", ".cache"} for part in path.relative_to(root).parts):
            continue
        if not path.is_file() or path.suffix.lower() not in {".lua", ".vim"}:
            continue
        file_size = path.stat().st_size
        if file_size > 1024 * 1024:
            continue
        if scanned_bytes + file_size > 8 * 1024 * 1024:
            return
        yield path
        emitted += 1
        scanned_bytes += file_size
        if emitted >= 500:
            return


def import_neovim(path: Path) -> dict[str, Any]:
    keybinds: list[dict[str, str]] = []
    for config_file in iter_neovim_files(path):
        try:
            text = config_file.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        relative = str(config_file.relative_to(path))
        if config_file.suffix.lower() == ".lua":
            keybinds.extend(neovim_lua_keybinds(text, relative))
        else:
            keybinds.extend(neovim_vimscript_keybinds(text, relative))
        if len(keybinds) >= 10000:
            keybinds = keybinds[:10000]
            break
    seen: set[tuple[str, str, str]] = set()
    unique: list[dict[str, str]] = []
    for entry in keybinds:
        signature = (entry["keys"], entry["description"], entry["context"])
        if signature not in seen:
            seen.add(signature)
            unique.append(entry)
    return page(
        "Neovim · local config", "terminal", "Neovim", "neovim-static", path, unique,
        "Partial static import: mappings created dynamically by plugins or Lua code may be missing.",
    )


def import_jetbrains(path: Path) -> dict[str, Any]:
    if path.stat().st_size > 5 * 1024 * 1024:
        raise ValueError("JetBrains keymap file is unexpectedly large")
    tree = ET.parse(path)
    keybinds: list[dict[str, str]] = []
    for action in tree.findall(".//action"):
        action_id = str(action.attrib.get("id", "")).strip()
        if not action_id:
            continue
        description = JETBRAINS_NAMES.get(action_id, humanize(action_id))
        for shortcut in action.findall("keyboard-shortcut"):
            if str(shortcut.attrib.get("remove", "")).lower() == "true":
                continue
            first = str(shortcut.attrib.get("first-keystroke", "")).strip()
            second = str(shortcut.attrib.get("second-keystroke", "")).strip()
            keys = " ".join(part for part in (first, second) if part)
            if keys:
                keybinds.append({
                    "keys": keys,
                    "description": description,
                    "category": "Custom keymap",
                    "context": "",
                    "notes": action_id,
                })
    product = next((part for part in path.parts if part.startswith(("IntelliJIdea", "IdeaIC", "PyCharm", "WebStorm", "CLion", "GoLand", "Rider"))), "JetBrains")
    display = re.sub(r"(?<=[A-Za-z])(?=\d)", " ", product)
    return page(display + " · custom", "deployed_code", display, "jetbrains", path, keybinds,
                "Imported from a custom JetBrains keymap. Built-in defaults are available as a starter template.")


def import_source(kind: str, path: Path) -> dict[str, Any]:
    if kind == "vscode":
        return import_vscode(path)
    if kind == "neovim":
        return import_neovim(path)
    if kind == "jetbrains":
        return import_jetbrains(path)
    raise ValueError(f"Unsupported source kind: {kind}")


def discover() -> list[dict[str, Any]]:
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    flatpak_home = Path.home() / ".var" / "app"
    sources: list[dict[str, Any]] = []

    vscode_candidates = [
        ("Visual Studio Code", config_home / "Code" / "User" / "keybindings.json"),
        ("Visual Studio Code OSS", config_home / "Code - OSS" / "User" / "keybindings.json"),
        ("VSCodium", config_home / "VSCodium" / "User" / "keybindings.json"),
        ("Cursor", config_home / "Cursor" / "User" / "keybindings.json"),
        ("Visual Studio Code · Flatpak", flatpak_home / "com.visualstudio.code" / "config" / "Code" / "User" / "keybindings.json"),
        ("VSCodium · Flatpak", flatpak_home / "com.vscodium.codium" / "config" / "VSCodium" / "User" / "keybindings.json"),
    ]
    for label, candidate in vscode_candidates:
        if not candidate.is_file():
            continue
        try:
            count = len(import_vscode(candidate)["keybinds"])
        except (OSError, ValueError, json.JSONDecodeError):
            count = 0
        sources.append({
            "id": "vscode:" + str(candidate), "kind": "vscode", "path": str(candidate),
            "name": label, "icon": "code", "count": count, "confidence": "high",
            "detail": "User keybindings.json",
        })

    neovim_root = config_home / "nvim"
    if neovim_root.is_dir():
        try:
            count = len(import_neovim(neovim_root)["keybinds"])
        except OSError:
            count = 0
        sources.append({
            "id": "neovim:" + str(neovim_root), "kind": "neovim", "path": str(neovim_root),
            "name": "Neovim", "icon": "terminal", "count": count, "confidence": "partial",
            "detail": "Static scan of Lua/Vimscript mappings",
        })

    jetbrains_patterns = [
        str(config_home / "JetBrains" / "*" / "keymaps" / "*.xml"),
        str(flatpak_home / "com.jetbrains.*" / "config" / "JetBrains" / "*" / "keymaps" / "*.xml"),
    ]
    jetbrains_paths = sorted({raw_path for pattern in jetbrains_patterns for raw_path in glob.glob(pattern)})
    for raw_path in jetbrains_paths:
        candidate = Path(raw_path)
        try:
            imported = import_jetbrains(candidate)
            count = len(imported["keybinds"])
            label = imported["name"]
        except (OSError, ValueError, ET.ParseError):
            count = 0
            label = "JetBrains · " + candidate.stem
        sources.append({
            "id": "jetbrains:" + str(candidate), "kind": "jetbrains", "path": str(candidate),
            "name": label, "icon": "deployed_code", "count": count, "confidence": "high",
            "detail": "Custom keymap XML",
        })
    return sources


def main(argv: list[str]) -> None:
    if len(argv) == 2 and argv[1] == "scan":
        emit({"ok": True, "sources": discover()})
    if len(argv) == 4 and argv[1] == "import":
        kind = argv[2]
        source_path = Path(argv[3]).expanduser()
        if not source_path.exists():
            emit({"ok": False, "error": "Shortcut source no longer exists."}, 1)
        try:
            imported = import_source(kind, source_path)
        except (OSError, ValueError, json.JSONDecodeError, ET.ParseError) as error:
            emit({"ok": False, "error": str(error)}, 1)
        if not imported["keybinds"]:
            emit({"ok": False, "error": "No statically readable shortcuts were found."}, 1)
        emit({"ok": True, "page": imported})
    emit({"ok": False, "error": "Usage: import_keybinds.py scan | import KIND PATH"}, 2)


if __name__ == "__main__":
    main(sys.argv)

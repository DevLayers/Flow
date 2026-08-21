#!/usr/bin/env python3
"""Generate the Settings search index outside the Quickshell process.

The Settings pages are QML and their controls already carry the useful facts:
their Config binding, label, range, choices, section, and sometimes an enabled
dependency.  Reading those files from the shell every time the Settings window
opens is both costly and insufficient for tools, because the old registry does
not preserve the Config key.  This module deliberately keeps the parser small
and deterministic instead of trying to evaluate QML.

It is an infrastructure command, not an AI tool.  The shell can call ``check``
once per session and rebuild in the background when the source fingerprint is
out of date.  ``search`` and ``get`` are also useful for testing and for the
future Settings/overview consumers.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
import unicodedata
from collections.abc import Iterable
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_ROOT = SCRIPT_DIR.parents[1]
DEFAULT_CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "illogical-impulse/config.json"
DEFAULT_OUTPUT = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell/user/ai/settings_index.json"

WIDGETS: dict[str, tuple[str, str]] = {
    "ConfigSwitch": ("bool", "checked"),
    "ConfigSpinBox": ("int", "value"),
    "ConfigSlider": ("real", "value"),
    "ConfigSelectionArray": ("enum", "currentValue"),
    "ConfigComboBox": ("enum", "currentValue"),
    "DynamicConfigSelectionArray": ("enum", "currentValue"),
    "ConfigTextField": ("string", "inputText"),
    "ConfigLightDarkToggle": ("enum", "currentValue"),
}


def normalize(value: object) -> str:
    """Lowercase a human-searchable value while keeping accent-free matches."""
    text = unicodedata.normalize("NFKD", str(value or ""))
    text = "".join(char for char in text if not unicodedata.combining(char))
    return text.lower()


def tokenize(value: object) -> list[str]:
    return [token for token in re.split(r"[^\w]+", normalize(value)) if len(token) > 1]


def _matching_end(text: str, start: int, opening: str = "{", closing: str = "}") -> int | None:
    """Return the matching delimiter while ignoring quoted strings/comments."""
    depth = 0
    quote = ""
    escaped = False
    line_comment = False
    block_comment = False
    index = start
    while index < len(text):
        char = text[index]
        next_char = text[index + 1] if index + 1 < len(text) else ""
        if line_comment:
            if char == "\n":
                line_comment = False
            index += 1
            continue
        if block_comment:
            if char == "*" and next_char == "/":
                block_comment = False
                index += 2
                continue
            index += 1
            continue
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
            index += 1
            continue
        if char in ("'", '"', "`"):
            quote = char
            index += 1
            continue
        if char == "/" and next_char == "/":
            line_comment = True
            index += 2
            continue
        if char == "/" and next_char == "*":
            block_comment = True
            index += 2
            continue
        if char == opening:
            depth += 1
        elif char == closing:
            depth -= 1
            if depth == 0:
                return index
        index += 1
    return None


def extract_blocks(text: str, component: str) -> list[dict[str, Any]]:
    """Port of SearchRegistry.extractBlocks, with comment-aware balancing."""
    results: list[dict[str, Any]] = []
    pattern = re.compile(rf"(?<![A-Za-z0-9_]){re.escape(component)}\s*{{")
    for match in pattern.finditer(text):
        brace = text.find("{", match.start(), match.end())
        end = _matching_end(text, brace)
        if end is None:
            continue
        results.append({
            "start": match.start(),
            "end": end + 1,
            "innerStart": brace + 1,
            "inner": text[brace + 1:end],
        })
    return results


def property_expression(block: str, name: str) -> str:
    """Read a simple QML property expression without evaluating it."""
    pattern = re.compile(rf"(?:^|\n)\s*{re.escape(name)}\s*:\s*([^\n]+)")
    match = pattern.search(block)
    return match.group(1).strip().rstrip(";") if match else ""


def text_from_expression(expression: str) -> str:
    """Extract static text from Translation.tr() or a quoted QML expression."""
    if not expression:
        return ""
    translated = re.search(r"Translation\.tr\(\s*(['\"])(.*?)\1", expression)
    if translated:
        return translated.group(2)
    literal = re.match(r"\s*(['\"])(.*?)\1", expression)
    return literal.group(2) if literal else ""


def config_key(expression: str) -> str:
    match = re.search(r"\bConfig\.options\.([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)", expression)
    return match.group(1) if match else ""


def config_key_for_widget(block: str, binding: str) -> str:
    key = config_key(property_expression(block, binding))
    if key:
        return key
    # A few older controls bind through an alias.  Preserve the first direct
    # Config binding rather than silently losing an otherwise usable setting.
    return config_key(block)


def qml_value(expression: str) -> Any:
    expression = expression.strip().rstrip(",")
    quoted = re.fullmatch(r"(['\"])(.*?)\1", expression)
    if quoted:
        return quoted.group(2)
    if expression == "true":
        return True
    if expression == "false":
        return False
    try:
        return float(expression) if "." in expression else int(expression)
    except ValueError:
        return None


def option_values(block: str) -> list[dict[str, Any]]:
    """Extract the stable display/value pairs from ConfigSelectionArray."""
    match = re.search(r"(?:^|\n)\s*options\s*:\s*\[", block)
    if not match:
        return []
    opening = block.find("[", match.start())
    end = _matching_end(block, opening, "[", "]")
    if end is None:
        return []
    values: list[dict[str, Any]] = []
    for option in extract_blocks(block[opening + 1:end], ""):
        # extract_blocks needs a component name; objects in an array have no
        # name, so this branch is deliberately unreachable.  Keep the robust
        # parser below explicit instead of treating JS object text as JSON.
        del option
    array = block[opening + 1:end]
    index = 0
    while index < len(array):
        start = array.find("{", index)
        if start < 0:
            break
        finish = _matching_end(array, start)
        if finish is None:
            break
        entry = array[start + 1:finish]
        value = qml_value(property_expression(entry, "value"))
        if value is not None:
            values.append({
                "label": text_from_expression(property_expression(entry, "displayName")),
                "value": value,
            })
        index = finish + 1
    return values


def parse_pages(registry_path: Path) -> list[dict[str, Any]]:
    text = registry_path.read_text(encoding="utf-8")
    pages_marker = text.find("readonly property var pages")
    if pages_marker < 0:
        raise ValueError(f"could not find pages in {registry_path}")
    opening = text.find("[", pages_marker)
    closing = _matching_end(text, opening, "[", "]")
    if closing is None:
        raise ValueError(f"could not parse pages in {registry_path}")
    pages_text = text[opening + 1:closing]
    pages: list[dict[str, Any]] = []
    index = 0
    while index < len(pages_text):
        start = pages_text.find("{", index)
        if start < 0:
            break
        end = _matching_end(pages_text, start)
        if end is None:
            break
        entry = pages_text[start + 1:end]
        field = lambda name: re.search(rf'"{re.escape(name)}"\s*:\s*"([^"]*)"', entry)
        identifier = field("id")
        component = field("component")
        if identifier and component:
            def strings(name: str) -> list[str]:
                array = re.search(rf'"{re.escape(name)}"\s*:\s*\[([^\]]*)\]', entry, re.S)
                return re.findall(r'"([^"]+)"', array.group(1)) if array else []

            pages.append({
                "id": identifier.group(1),
                "name": field("name").group(1) if field("name") else identifier.group(1),
                "component": component.group(1),
                "subPages": strings("subPages"),
                "searchSources": strings("searchSources"),
                "aliases": strings("aliases"),
                "searchable": not bool(re.search(r'"searchable"\s*:\s*false', entry)),
            })
        index = end + 1
    return pages


def source_records(root: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    config_root = root / "modules/settings/configs"
    for page in parse_pages(root / "modules/common/SettingsPageRegistry.qml"):
        if not page["searchable"]:
            continue
        records.append({**page, "path": root / page["component"], "subPage": ""})
        for subpage in page["subPages"]:
            records.append({**page, "path": config_root / subpage, "subPage": subpage})
        for source in page["searchSources"]:
            records.append({**page, "path": config_root / source, "subPage": ""})
    return records


def localized(value: str, translations: dict[str, Any]) -> str:
    translated = translations.get(value)
    return translated if isinstance(translated, str) and translated else value


def flat_config(value: Any, prefix: str = "") -> Iterable[tuple[str, Any]]:
    if isinstance(value, dict):
        for key, nested in value.items():
            yield from flat_config(nested, f"{prefix}.{key}" if prefix else key)
    elif prefix:
        yield prefix, value


def value_type(value: Any) -> str:
    if isinstance(value, bool):
        return "bool"
    if isinstance(value, int):
        return "int"
    if isinstance(value, float):
        return "real"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "list"
    return "unknown"


def source_fingerprint(root: Path, language: str) -> str:
    records = source_records(root)
    paths = [root / "modules/common/SettingsPageRegistry.qml", root / "translations" / f"{language}.json", root / "scripts/ai/settings_synonyms.json"]
    paths.extend(record["path"] for record in records)
    digest = hashlib.sha256()
    for path in sorted({path.resolve() for path in paths if path.exists()}):
        stat = path.stat()
        try:
            relative = path.relative_to(root)
        except ValueError:
            relative = path
        digest.update(f"{relative}\0{stat.st_mtime_ns}\0{stat.st_size}\n".encode("utf-8"))
    return digest.hexdigest()


def _section_for(offset: int, sections: list[dict[str, Any]], translations: dict[str, Any]) -> tuple[str, str, str]:
    containing = [section for section in sections if section["start"] <= offset < section["end"]]
    if not containing:
        return "", "", ""
    section = min(containing, key=lambda item: item["end"] - item["start"])
    title = text_from_expression(property_expression(section["inner"], "title"))
    return title, localized(title, translations), text_from_expression(property_expression(section["inner"], "icon"))


def extract_entries(record: dict[str, Any], root: Path, translations: dict[str, Any]) -> list[dict[str, Any]]:
    path: Path = record["path"]
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8")
    sections = extract_blocks(text, "ContentSection") + extract_blocks(text, "ContentSubsection")
    entries: list[dict[str, Any]] = []
    for widget, (widget_type, binding) in WIDGETS.items():
        for block in extract_blocks(text, widget):
            key = config_key_for_widget(block["inner"], binding)
            if not key:
                continue
            label = ""
            for property_name in ("text", "title", "label", "placeholderText"):
                label = text_from_expression(property_expression(block["inner"], property_name))
                if label:
                    break
            description = text_from_expression(property_expression(block["inner"], "description"))
            if not description:
                for tooltip in extract_blocks(block["inner"], "StyledToolTip"):
                    description = text_from_expression(property_expression(tooltip["inner"], "text"))
                    if description:
                        break
            section, section_localized, section_icon = _section_for(block["start"], sections, translations)
            icon = text_from_expression(property_expression(block["inner"], "icon"))
            if not icon:
                icon = text_from_expression(property_expression(block["inner"], "buttonIcon")) or section_icon
            entry: dict[str, Any] = {
                "key": key,
                "type": widget_type,
                "widget": widget,
                "hasUi": True,
                "label": label or key.rsplit(".", 1)[-1],
                "labelLocalized": localized(label or key.rsplit(".", 1)[-1], translations),
                "description": description,
                "descriptionLocalized": localized(description, translations),
                "icon": icon,
                "pageId": record["id"],
                "pageName": record["name"],
                "pageNameLocalized": localized(record["name"], translations),
                "sectionTitle": section,
                "sectionTitleLocalized": section_localized,
                "subPage": record["subPage"],
                "aliases": list(record["aliases"]),
                "source": str(path.relative_to(root)),
                "blockStart": block["start"],
                "blockEnd": block["end"],
            }
            if widget in ("ConfigSpinBox", "ConfigSlider"):
                lower = qml_value(property_expression(block["inner"], "from"))
                upper = qml_value(property_expression(block["inner"], "to"))
                step = qml_value(property_expression(block["inner"], "stepSize"))
                if lower is not None or upper is not None or step is not None:
                    entry["range"] = {"from": lower, "to": upper, "step": step}
            options = option_values(block["inner"])
            if options:
                entry["options"] = options
            enabled_key = config_key(property_expression(block["inner"], "enabled"))
            if enabled_key:
                entry["dependsOn"] = enabled_key
            entries.append(entry)
    return entries


def load_json(path: Path, default: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return default


def build_index(*, root: Path = DEFAULT_ROOT, config_path: Path = DEFAULT_CONFIG, language: str = "pt_BR", output_path: Path = DEFAULT_OUTPUT) -> dict[str, Any]:
    root = Path(root).resolve()
    config_path = Path(config_path)
    translations = load_json(root / "translations" / f"{language}.json", {})
    synonyms = load_json(root / "scripts/ai/settings_synonyms.json", {})
    config = load_json(config_path, {})
    leaves = dict(flat_config(config))
    merged: dict[str, dict[str, Any]] = {}

    for record in source_records(root):
        for entry in extract_entries(record, root, translations):
            entry["currentValue"] = leaves.get(entry["key"])
            if entry["key"] in leaves:
                # The persisted type is authoritative.  Widgets provide the
                # useful UI shape, but QML may expose an int as a real alias.
                value_kind = value_type(leaves[entry["key"]])
                if entry["type"] != "enum":
                    entry["type"] = value_kind
            existing = merged.get(entry["key"])
            if existing is None:
                merged[entry["key"]] = entry
            else:
                location = {"pageId": entry["pageId"], "subPage": entry["subPage"]}
                if location != {"pageId": existing["pageId"], "subPage": existing["subPage"]}:
                    existing.setdefault("alsoIn", []).append(location)

    for key, value in leaves.items():
        if key in merged:
            continue
        merged[key] = {
            "key": key,
            "type": value_type(value),
            "widget": "",
            "hasUi": False,
            "label": key.rsplit(".", 1)[-1],
            "labelLocalized": key.rsplit(".", 1)[-1],
            "description": "",
            "descriptionLocalized": "",
            "icon": "settings",
            "pageId": "",
            "pageName": "",
            "pageNameLocalized": "",
            "sectionTitle": "",
            "sectionTitleLocalized": "",
            "subPage": "",
            "aliases": [],
            "source": "config.json",
            "blockStart": -1,
            "blockEnd": -1,
            "currentValue": value,
        }

    for entry in merged.values():
        haystack = " ".join([entry["key"], entry["label"], entry["labelLocalized"], entry["description"], entry["descriptionLocalized"], entry["sectionTitle"], entry["sectionTitleLocalized"], entry["pageName"], *entry["aliases"]])
        domains = [domain for domain in synonyms if domain in normalize(haystack)]
        keywords = sorted({word for domain in domains for word in [domain, *synonyms.get(domain, [])]})
        entry["keywords"] = keywords

    index = {
        "schema": SCHEMA_VERSION,
        "generatedAt": int(time.time()),
        "sourceHash": source_fingerprint(root, language),
        "language": language,
        "entries": sorted(merged.values(), key=lambda entry: entry["key"]),
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(index, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return index


def index_is_current(index: dict[str, Any], root: Path = DEFAULT_ROOT, language: str = "pt_BR") -> bool:
    return index.get("schema") == SCHEMA_VERSION and index.get("language") == language and index.get("sourceHash") == source_fingerprint(Path(root).resolve(), language)


def load_index(path: Path) -> dict[str, Any]:
    index = load_json(path, {})
    if not isinstance(index, dict) or not isinstance(index.get("entries"), list):
        raise ValueError(f"invalid settings index: {path}")
    return index


def search_entries(index: dict[str, Any], query: str, limit: int = 8) -> list[dict[str, Any]]:
    """Score lexical matches using the ranking published in the integration plan."""
    query_normalized = normalize(query).strip()
    query_tokens = tokenize(query_normalized)
    if not query_tokens:
        return []
    found: list[dict[str, Any]] = []
    for original in index.get("entries", []):
        label = normalize(original.get("label"))
        localized_label = normalize(original.get("labelLocalized"))
        key = normalize(original.get("key"))
        last_key = key.rsplit(".", 1)[-1]
        description = normalize(f"{original.get('description', '')} {original.get('descriptionLocalized', '')}")
        navigation = normalize(" ".join([*original.get("aliases", []), original.get("pageName", ""), original.get("sectionTitle", ""), original.get("sectionTitleLocalized", "")]))
        keywords = [normalize(keyword) for keyword in original.get("keywords", [])]
        score = 40 if original.get("hasUi") else 0
        for token in query_tokens:
            if token == label or token == localized_label:
                score += 500
            elif label.startswith(token) or localized_label.startswith(token):
                score += 200
            if token == last_key or token in tokenize(last_key):
                score += 180
            if token in description:
                score += 120
            if token in navigation:
                score += 100
            if token in keywords:
                score += 90
        if query_normalized == label or query_normalized == localized_label:
            score += 500
        if score <= (40 if original.get("hasUi") else 0):
            continue
        entry = dict(original)
        entry["score"] = score
        found.append(entry)
    return sorted(found, key=lambda entry: (-entry["score"], not entry.get("hasUi"), entry["key"]))[:max(1, min(int(limit), 8))]


def _arguments() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT, help="II repository root")
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG, help="config.json to introspect")
    parser.add_argument("--lang", default="pt_BR", help="translation locale")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUTPUT, help="index JSON path")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("build")
    commands.add_parser("check")
    search = commands.add_parser("search")
    search.add_argument("query")
    search.add_argument("--limit", type=int, default=8)
    get = commands.add_parser("get")
    get.add_argument("key")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _arguments().parse_args(argv)
    if args.command == "build":
        index = build_index(root=args.root, config_path=args.config, language=args.lang, output_path=args.out)
        print(json.dumps({"entries": len(index["entries"]), "sourceHash": index["sourceHash"], "out": str(args.out)}, ensure_ascii=False))
        return 0
    try:
        index = load_index(args.out)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1
    if args.command == "check":
        current = index_is_current(index, args.root, args.lang)
        print(index.get("sourceHash", ""))
        return 0 if current else 1
    if args.command == "search":
        print(json.dumps(search_entries(index, args.query, args.limit), ensure_ascii=False, indent=2))
        return 0
    for entry in index["entries"]:
        if entry.get("key") == args.key:
            print(json.dumps(entry, ensure_ascii=False, indent=2))
            return 0
    print(f"unknown setting key: {args.key}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

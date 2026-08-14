#!/usr/bin/env python3
"""Attachment side of the AI sidebar: what a file is, and how it gets into a request.

Two jobs, both of which QML cannot do on its own:

  probe PATH          What is this file? Prints one JSON object describing it,
                      so the composer can show it, size-check it and decide
                      whether the model in use can read it at all.

  inject BODY SPEC    Puts the files into an already-built request body. SPEC
                      is a JSON array of {marker, mode, path}; every marker is
                      replaced in place by the file, either base64-encoded
                      ("b64") or as JSON-escaped text ("text").

Injection happens here rather than in the shell because a base64 image is far
past what a single command-line argument can hold, and past what is comfortable
to quote by hand. The body is a file, curl reads it with --data-binary, and
nothing large ever passes through argv.
"""

import base64
import json
import mimetypes
import os
import sys

# Enough of a signature to name the common extensionless cases — clipboard
# images land in a file named after their cliphist id, with no extension at all.
SIGNATURES = [
    (b"\x89PNG\r\n\x1a\n", "image/png"),
    (b"\xff\xd8\xff", "image/jpeg"),
    (b"GIF87a", "image/gif"),
    (b"GIF89a", "image/gif"),
    (b"BM", "image/bmp"),
    (b"%PDF-", "application/pdf"),
]

TEXT_MIME_PREFIXES = ("text/",)
TEXT_MIMES = {
    "application/json",
    "application/javascript",
    "application/x-javascript",
    "application/xml",
    "application/x-sh",
    "application/x-shellscript",
    "application/x-yaml",
    "application/toml",
    "application/x-python-code",
}
# Extensions that are plainly source but that mimetypes calls octet-stream.
CODE_EXTENSIONS = {
    ".qml", ".rs", ".go", ".kt", ".swift", ".ts", ".tsx", ".jsx", ".vue",
    ".toml", ".yaml", ".yml", ".ini", ".conf", ".cfg", ".env", ".lua",
    ".zig", ".nim", ".hs", ".sql", ".gradle", ".dockerfile", ".make",
}


def sniff(path: str) -> str:
    try:
        with open(path, "rb") as handle:
            head = handle.read(16)
    except OSError:
        return ""
    for signature, mime in SIGNATURES:
        if head.startswith(signature):
            return mime
    # Anything that decodes as UTF-8 and holds no NUL is treated as text: the
    # point is only to decide between "paste it in" and "base64 it".
    if b"\x00" in head:
        return ""
    try:
        head.decode("utf-8")
    except UnicodeDecodeError:
        return ""
    return "text/plain"


def mime_of(path: str) -> str:
    guessed, _ = mimetypes.guess_type(path)
    extension = os.path.splitext(path)[1].lower()
    if extension in CODE_EXTENSIONS:
        return "text/plain"
    if guessed:
        return guessed
    return sniff(path) or "application/octet-stream"


def kind_of(mime: str) -> str:
    if mime.startswith("image/"):
        return "image"
    if mime == "application/pdf":
        return "pdf"
    if mime.startswith("audio/"):
        return "audio"
    if mime.startswith("video/"):
        return "video"
    if mime.startswith(TEXT_MIME_PREFIXES) or mime in TEXT_MIMES:
        return "text"
    return "other"


def probe(path: str) -> dict:
    path = os.path.expanduser(path)
    if not os.path.isfile(path):
        return {"error": f"No file at {path}", "path": path}
    try:
        size = os.path.getsize(path)
    except OSError as error:
        return {"error": str(error), "path": path}
    mime = mime_of(path)
    return {
        "path": path,
        "name": os.path.basename(path),
        "mime": mime,
        "kind": kind_of(mime),
        "bytes": size,
    }


def encoded(mode: str, path: str) -> str:
    with open(path, "rb") as handle:
        raw = handle.read()
    if mode == "text":
        text = raw.decode("utf-8", errors="replace")
        # Trimmed of the surrounding quotes: the marker already sits inside a
        # JSON string in the body.
        return json.dumps(text)[1:-1]
    return base64.b64encode(raw).decode("ascii")


def inject(body_path: str, spec_raw: str) -> dict:
    try:
        spec = json.loads(spec_raw)
    except json.JSONDecodeError as error:
        return {"error": f"Unreadable attachment spec: {error}"}
    try:
        with open(body_path, "r", encoding="utf-8") as handle:
            body = handle.read()
    except OSError as error:
        return {"error": str(error)}

    failures = []
    for item in spec:
        marker = item.get("marker", "")
        path = os.path.expanduser(item.get("path", ""))
        if not marker or not path:
            continue
        try:
            body = body.replace(marker, encoded(item.get("mode", "b64"), path))
        except OSError as error:
            # The request still goes out: an attachment that vanished between
            # being picked and being sent is worth a note, not a dead request.
            body = body.replace(marker, "")
            failures.append(f"{os.path.basename(path)}: {error.strerror}")

    try:
        with open(body_path, "w", encoding="utf-8") as handle:
            handle.write(body)
    except OSError as error:
        return {"error": str(error)}
    return {"injected": len(spec), "failed": failures}


def main() -> int:
    if len(sys.argv) < 3:
        print(json.dumps({"error": "usage: ai_attach.py probe PATH | inject BODY SPEC"}))
        return 0
    command = sys.argv[1]
    if command == "probe":
        print(json.dumps(probe(sys.argv[2])))
        return 0
    if command == "inject":
        if len(sys.argv) < 4:
            print(json.dumps({"error": "inject needs a body path and a spec"}))
            return 0
        print(json.dumps(inject(sys.argv[2], sys.argv[3])))
        return 0
    print(json.dumps({"error": f"Unknown command: {command}"}))
    return 0


if __name__ == "__main__":
    sys.exit(main())

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
import shutil
import select
import subprocess
import sys
import time

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

# Never offer obvious credentials to a model merely because they happen to
# look like text. A user can still paste a deliberately redacted value into
# the composer, but attaching a secret file requires an explicit local edit.
SENSITIVE_BASENAMES = {
    ".env", ".env.local", ".env.production", ".env.development",
    "credentials.json", "credentials.yaml", "credentials.yml",
    "secrets.json", "secrets.yaml", "secrets.yml",
    "id_rsa", "id_ed25519", "id_ecdsa", "private.key",
}
SENSITIVE_SEGMENTS = {
    ".ssh", ".gnupg", ".aws", ".kube", ".docker",
    "keyrings", "browser", "chromium", "mozilla",
}


def is_sensitive_path(path: str) -> bool:
    """Whether a path belongs to a high-risk credential/config location."""
    expanded = os.path.realpath(os.path.expanduser(path))
    basename = os.path.basename(expanded).lower()
    if basename in SENSITIVE_BASENAMES or basename.startswith(".env."):
        return True
    segments = {segment.lower() for segment in expanded.split(os.sep) if segment}
    return bool(segments.intersection(SENSITIVE_SEGMENTS))


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
    if is_sensitive_path(path):
        return {
            "error": "This file looks like a credential or secret and was blocked for safety.",
            "path": path,
            "sensitive": True,
        }
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
        # Whether this machine can turn it into text if the model cannot read
        # the format itself.
        "extractable": extractor_for(mime) is not None,
    }


# Documents that no chat API takes as a document, but that this machine can
# turn into text before anything leaves it.
EXTRACTORS = {
    "application/pdf": [["pdftotext", "-layout", "{src}", "-"]],
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": [
        ["pandoc", "-t", "plain", "{src}"],
    ],
    "application/msword": [["pandoc", "-t", "plain", "{src}"]],
    "application/vnd.oasis.opendocument.text": [["pandoc", "-t", "plain", "{src}"]],
    "application/epub+zip": [["pandoc", "-t", "plain", "{src}"]],
    "application/rtf": [["pandoc", "-t", "plain", "{src}"]],
}


def extractor_for(mime: str):
    """The first extraction command whose tool is actually installed."""
    for command in EXTRACTORS.get(mime, []):
        if shutil.which(command[0]):
            return command
    return None


def extract(path: str, limit: int = 400_000) -> dict:
    """Turns a document into plain text, so a model that only reads text can
    still be asked about it. Truncation is reported rather than hidden."""
    path = os.path.expanduser(path)
    if not os.path.isfile(path):
        return {"error": f"No file at {path}", "path": path}
    if is_sensitive_path(path):
        return {
            "error": "This file looks like a credential or secret and was blocked for safety.",
            "path": path,
            "sensitive": True,
        }
    mime = mime_of(path)
    command = extractor_for(mime)
    if command is None:
        return {"error": f"No extractor for {mime}", "path": path, "mime": mime}
    filled = [part.replace("{src}", path) for part in command]
    try:
        process = subprocess.Popen(filled, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        # Read only one byte past the cap. Large PDFs must not be copied in
        # full into a Python/QML buffer just to discover that they are long.
        chunks = []
        total = 0
        truncated = False
        deadline = time.monotonic() + 60
        while True:
            remaining_time = deadline - time.monotonic()
            if remaining_time <= 0:
                process.kill()
                process.wait()
                return {"error": "Document extraction timed out", "path": path, "mime": mime}
            ready, _, _ = select.select([process.stdout], [], [], remaining_time)
            if not ready:
                process.kill()
                process.wait()
                return {"error": "Document extraction timed out", "path": path, "mime": mime}
            chunk = os.read(process.stdout.fileno(), min(65536, limit + 1 - total))
            if not chunk:
                break
            chunks.append(chunk)
            total += len(chunk)
            if total > limit:
                truncated = True
                process.kill()
                process.wait()
                break
        output = b"".join(chunks)
        process.wait(timeout=max(1, int(deadline - time.monotonic())))
        returncode = process.returncode
    except (OSError, subprocess.SubprocessError) as error:
        return {"error": str(error), "path": path, "mime": mime}
    if returncode != 0 and not truncated:
        return {"error": f"{command[0]} failed", "path": path, "mime": mime}
    text = output[:limit].decode("utf-8", errors="replace").strip()
    return {
        "path": path,
        "name": os.path.basename(path),
        "mime": mime,
        "text": text,
        "characters": len(text),
        "truncated": truncated,
    }


def encoded(mode: str, path: str) -> str:
    if is_sensitive_path(path):
        raise OSError("attachment blocked: credential or secret path")
    if mode == "extract":
        # A document the model cannot read as a document. It is turned into
        # text here, at send time, so the whole extraction never sits in the
        # shell's memory or in the saved session.
        result = extract(path)
        if result.get("error") or not result.get("text"):
            raise OSError(result.get("error") or "extraction returned nothing")
        note = "\n\n[[ truncated ]]" if result.get("truncated") else ""
        return json.dumps(result["text"] + note)[1:-1]
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
            # The caller aborts the request when any attachment has vanished
            # between being picked and being sent, or could not be read.
            body = body.replace(marker, "")
            failures.append(f"{os.path.basename(path)}: {error.strerror or error}")

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
    if command == "extract":
        if len(sys.argv) < 3:
            print(json.dumps({"error": "extract needs a path"}))
            return 1
        print(json.dumps(extract(sys.argv[2])))
        return 0
    if command == "probe":
        print(json.dumps(probe(sys.argv[2])))
        return 0
    if command == "inject":
        if len(sys.argv) < 4:
            print(json.dumps({"error": "inject needs a body path and a spec"}))
            return 1
        result = inject(sys.argv[2], sys.argv[3])
        print(json.dumps(result))
        return 1 if result.get("error") or result.get("failed") else 0
    print(json.dumps({"error": f"Unknown command: {command}"}))
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Bounded, read-only Gmail bridge for the AI integration.

The process accepts one JSON request on stdin and returns one JSON response.
It always obtains message metadata before an explicit body read and never
returns attachment payloads.
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


EMAIL_DIR = Path(__file__).resolve().parents[1] / "email"
sys.path.insert(0, str(EMAIL_DIR))

import fetch_email_body  # noqa: E402
import gmail_config  # noqa: E402


API_ROOT = "https://gmail.googleapis.com/gmail/v1/users/me"
MAX_RESULTS = 10
MAX_BODY_CHARS = 12000
MAX_QUERY_CHARS = 500


def api_get(path: str, token: str) -> dict:
    request = urllib.request.Request(
        API_ROOT + path,
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        value = json.loads(response.read().decode("utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError("Gmail returned an invalid object")
    return value


def headers_for(message: dict) -> dict[str, str]:
    headers = {}
    for header in (message.get("payload") or {}).get("headers", []):
        name = str(header.get("name", "")).lower()
        if name in {"subject", "from", "to", "date", "message-id"} and name not in headers:
            headers[name] = str(header.get("value", ""))[:500]
    return headers


def metadata_dto(message: dict) -> dict:
    headers = headers_for(message)
    internal_date = str(message.get("internalDate", ""))
    try:
        timestamp = int(internal_date) // 1000 if internal_date else 0
    except ValueError:
        timestamp = 0
    return {
        "id": str(message.get("id", "")),
        "threadId": str(message.get("threadId", "")),
        "subject": headers.get("subject", ""),
        "from": headers.get("from", ""),
        "to": headers.get("to", ""),
        "date": headers.get("date", ""),
        "timestamp": timestamp,
        "snippet": str(message.get("snippet", ""))[:360],
        "labels": [str(label) for label in message.get("labelIds", [])[:12]],
    }


def message_metadata(token: str, message_id: str) -> dict:
    encoded_id = urllib.parse.quote(message_id, safe="")
    query = urllib.parse.urlencode(
        [
            ("format", "metadata"),
            ("metadataHeaders", "Subject"),
            ("metadataHeaders", "From"),
            ("metadataHeaders", "To"),
            ("metadataHeaders", "Date"),
            ("metadataHeaders", "Message-ID"),
        ]
    )
    return api_get(f"/messages/{encoded_id}?{query}", token)


def body_dto(message: dict, mode: str) -> dict:
    payload = message.get("payload") or {}
    html_body, plain_body, _attachments = fetch_email_body.extract_parts(payload)
    plain = plain_body or str(message.get("snippet", ""))
    html = fetch_email_body.sanitize_html(html_body) if html_body else fetch_email_body.linkify_text(plain)
    if mode == "plainText":
        content = plain
    else:
        content = html
    content = str(content)[:MAX_BODY_CHARS]
    return {
        "body": content,
        "bodyMode": mode,
        "truncated": len(str(content)) >= MAX_BODY_CHARS,
    }


def valid_body_mode(value: object) -> str:
    mode = str(value or "metadata")
    if mode not in {"metadata", "plainText", "sanitizedHtml"}:
        raise ValueError("bodyMode must be metadata, plainText or sanitizedHtml")
    return mode


def search_messages(token: str, request: dict) -> dict:
    query_text = str(request.get("query", "")).strip()[:MAX_QUERY_CHARS]
    if not query_text:
        raise ValueError("query is required")
    limit = max(1, min(MAX_RESULTS, int(request.get("limit", 5))))
    params = [("q", query_text), ("maxResults", str(limit))]
    page_token = str(request.get("pageToken", "")).strip()[:200]
    if page_token:
        params.append(("pageToken", page_token))
    listing = api_get("/messages?" + urllib.parse.urlencode(params), token)
    messages = []
    for item in listing.get("messages", [])[:limit]:
        message_id = str(item.get("id", ""))
        if not message_id:
            continue
        metadata = message_metadata(token, message_id)
        messages.append(metadata_dto(metadata))
    return {
        "query": query_text,
        "messages": messages,
        "nextPageToken": str(listing.get("nextPageToken", ""))[:200],
        "limit": limit,
        "bodyMode": "metadata",
    }


def get_message(token: str, request: dict) -> dict:
    message_id = str(request.get("messageId", "")).strip()
    if not message_id:
        raise ValueError("messageId is required")
    mode = valid_body_mode(request.get("bodyMode"))
    metadata = message_metadata(token, message_id)
    result = {"message": metadata_dto(metadata), "bodyMode": mode}
    if mode != "metadata":
        full = api_get(f"/messages/{urllib.parse.quote(message_id, safe='')}?format=full", token)
        result.update(body_dto(full, mode))
    return result


def get_thread(token: str, request: dict) -> dict:
    thread_id = str(request.get("threadId", "")).strip()
    if not thread_id:
        raise ValueError("threadId is required")
    mode = valid_body_mode(request.get("bodyMode"))
    encoded_id = urllib.parse.quote(thread_id, safe="")
    metadata_thread = api_get(f"/threads/{encoded_id}?format=metadata", token)
    items = metadata_thread.get("messages", [])[:MAX_RESULTS]
    messages = [{"message": metadata_dto(item)} for item in items]
    if mode != "metadata":
        for entry in messages:
            message_id = entry["message"]["id"]
            full = api_get(f"/messages/{urllib.parse.quote(message_id, safe='')}?format=full", token)
            entry.update(body_dto(full, mode))
    return {
        "threadId": thread_id,
        "messages": messages,
        "bodyMode": mode,
        "truncated": len(metadata_thread.get("messages", [])) > MAX_RESULTS,
    }


def response(call_id: object, data: dict | None = None, error: str = "") -> dict:
    result = {"callId": str(call_id or ""), "ok": not bool(error)}
    if error:
        result["error"] = error
    else:
        result["data"] = data or {}
    return result


def main() -> int:
    try:
        request = json.loads(sys.stdin.read() or "{}")
        if not isinstance(request, dict):
            raise ValueError("request must be an object")
        call_id = request.get("callId", "")
        token_input = str(request.get("token", ""))
        if not token_input:
            raise ValueError("Gmail is not authenticated")
        token = gmail_config.resolve_token(token_input)
        operation = str(request.get("operation", ""))
        if operation == "search":
            data = search_messages(token, request)
        elif operation == "get":
            data = get_message(token, request)
        elif operation == "thread":
            data = get_thread(token, request)
        else:
            raise ValueError("unsupported Gmail operation")
        print(json.dumps(response(call_id, data), ensure_ascii=False))
        return 0
    except (ValueError, TypeError, urllib.error.URLError, urllib.error.HTTPError, RuntimeError) as error:
        print(json.dumps(response(locals().get("call_id", ""), error=str(error)), ensure_ascii=False))
        return 1
    except Exception:
        print(json.dumps(response(locals().get("call_id", ""), error="Gmail request failed"), ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Web access for the AI sidebar, as two small tools any model can call.

The providers that ship their own search only expose it to their own models,
so a local Qwen could never look anything up. These two commands close that:

  search QUERY [COUNT]   Searches and prints the results as JSON.
  fetch URL              Fetches a page and prints its readable text as JSON.

Search tries the backends in order: a local SearXNG (AI_SEARXNG_URL, default
http://127.0.0.1:8888), Brave (BRAVE_SEARCH_KEY), DuckDuckGo's HTML endpoint,
and Wikipedia. The last two need no key, but only Wikipedia answers reliably —
DuckDuckGo serves a challenge page to anything that is not a browser. Running
a local SearXNG is what makes this a real search; without one the model still
gets encyclopedic answers and can read any page with `fetch`.

Nothing here follows redirects to non-HTTP schemes, runs scripts, or writes
anything to disk.
"""

import html
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) quickshell-ai/1.0"
TIMEOUT = 20
MAX_TEXT = 20_000


def get(url: str, headers: dict | None = None) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, **(headers or {})})
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        return response.read().decode(charset, errors="replace")


def strip_tags(markup: str) -> str:
    """Readable text out of a page, without pulling in a parser."""
    markup = re.sub(r"(?is)<(script|style|noscript|template)\b.*?</\1>", " ", markup)
    markup = re.sub(r"(?is)<(nav|footer|aside|form)\b.*?</\1>", " ", markup)
    markup = re.sub(r"(?is)<br\s*/?>", "\n", markup)
    markup = re.sub(r"(?is)</(p|div|section|article|li|h[1-6]|tr)>", "\n", markup)
    text = re.sub(r"(?s)<[^>]+>", " ", markup)
    text = html.unescape(text)
    text = re.sub(r"[ \t\r\f\v]+", " ", text)
    text = re.sub(r"\n\s*\n\s*\n+", "\n\n", text)
    return text.strip()


def title_of(markup: str) -> str:
    match = re.search(r"(?is)<title[^>]*>(.*?)</title>", markup)
    return html.unescape(match.group(1)).strip() if match else ""


def searxng(query: str, count: int) -> list | None:
    base = os.environ.get("AI_SEARXNG_URL", "http://127.0.0.1:8888").rstrip("/")
    url = f"{base}/search?q={urllib.parse.quote(query)}&format=json"
    try:
        payload = json.loads(get(url))
    except Exception:
        return None
    results = []
    for item in payload.get("results", [])[:count]:
        results.append({
            "title": item.get("title", ""),
            "url": item.get("url", ""),
            "snippet": item.get("content", ""),
        })
    return results or None


def brave(query: str, count: int) -> list | None:
    key = os.environ.get("BRAVE_SEARCH_KEY", "").strip()
    if not key:
        return None
    url = f"https://api.search.brave.com/res/v1/web/search?q={urllib.parse.quote(query)}&count={count}"
    try:
        payload = json.loads(get(url, {"X-Subscription-Token": key, "Accept": "application/json"}))
    except Exception:
        return None
    results = []
    for item in payload.get("web", {}).get("results", [])[:count]:
        results.append({
            "title": item.get("title", ""),
            "url": item.get("url", ""),
            "snippet": strip_tags(item.get("description", "")),
        })
    return results or None


def wikipedia(query: str, count: int) -> list | None:
    """The one search that answers without a key or a captcha. Encyclopedic
    only, which is why it is last: it is a floor, not a search engine."""
    url = "https://en.wikipedia.org/w/api.php?" + urllib.parse.urlencode({
        "action": "query",
        "list": "search",
        "format": "json",
        "srsearch": query,
        "srlimit": count,
    })
    try:
        payload = json.loads(get(url, {"Accept": "application/json"}))
    except Exception:
        return None
    results = []
    for item in payload.get("query", {}).get("search", []):
        title = item.get("title", "")
        results.append({
            "title": title,
            "url": "https://en.wikipedia.org/wiki/" + urllib.parse.quote(title.replace(" ", "_")),
            "snippet": strip_tags(item.get("snippet", "")),
        })
    return results or None


def duckduckgo(query: str, count: int) -> list | None:
    url = f"https://html.duckduckgo.com/html/?q={urllib.parse.quote(query)}"
    try:
        markup = get(url)
    except Exception:
        return None
    results = []
    pattern = re.compile(
        r'(?is)<a[^>]+class="[^"]*result__a[^"]*"[^>]+href="(?P<href>[^"]+)"[^>]*>(?P<title>.*?)</a>'
        r'.*?(?:<a[^>]+class="[^"]*result__snippet[^"]*"[^>]*>(?P<snippet>.*?)</a>)?'
    )
    for match in pattern.finditer(markup):
        href = html.unescape(match.group("href"))
        # DuckDuckGo wraps every result in its own redirector.
        parsed = urllib.parse.urlparse(href)
        if parsed.path.startswith("/l/"):
            query_args = urllib.parse.parse_qs(parsed.query)
            href = query_args.get("uddg", [href])[0]
        results.append({
            "title": strip_tags(match.group("title")),
            "url": href,
            "snippet": strip_tags(match.group("snippet") or ""),
        })
        if len(results) >= count:
            break
    return results or None


def search(query: str, count: int) -> dict:
    query = query.strip()
    if not query:
        return {"error": "Empty query"}
    for backend, name in ((searxng, "searxng"), (brave, "brave"), (duckduckgo, "duckduckgo"), (wikipedia, "wikipedia")):
        results = backend(query, count)
        if results:
            return {"query": query, "engine": name, "results": results}
    return {
        "error": (
            "No search backend is reachable. Run a local SearXNG (AI_SEARXNG_URL, "
            "default http://127.0.0.1:8888) or set BRAVE_SEARCH_KEY; the keyless "
            "fallbacks are being refused right now."
        ),
        "query": query,
    }


def fetch(url: str) -> dict:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in ("http", "https"):
        return {"error": "Only http and https URLs can be fetched", "url": url}
    try:
        markup = get(url)
    except urllib.error.HTTPError as error:
        return {"error": f"HTTP {error.code}", "url": url}
    except Exception as error:
        return {"error": str(error), "url": url}
    text = strip_tags(markup)
    truncated = len(text) > MAX_TEXT
    return {
        "url": url,
        "title": title_of(markup),
        "text": text[:MAX_TEXT],
        "truncated": truncated,
    }


def main() -> int:
    if len(sys.argv) < 3:
        print(json.dumps({"error": "usage: ai_web.py search QUERY [COUNT] | fetch URL"}))
        return 0
    command = sys.argv[1]
    if command == "search":
        count = 5
        if len(sys.argv) > 3:
            try:
                count = max(1, min(10, int(sys.argv[3])))
            except ValueError:
                count = 5
        print(json.dumps(search(sys.argv[2], count)))
        return 0
    if command == "fetch":
        print(json.dumps(fetch(sys.argv[2])))
        return 0
    print(json.dumps({"error": f"Unknown command {command}"}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

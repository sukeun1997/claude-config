#!/usr/bin/env python3
"""
sentry-fetch.py — Sentry issue fetcher for sentry-debug skill.

Usage:
  sentry-fetch.py <issue_id_or_url> [--deep]

Environment:
  SENTRY_AUTH_TOKEN      — Sentry API auth token (required for default/prod)
  SENTRY_BASE_URL        — Sentry base URL, e.g. https://sentry.pfct.io (required)
  SENTRY_DEV_AUTH_TOKEN  — Dev Sentry token (optional; auto-used when URL host matches SENTRY_DEV_BASE_URL)
  SENTRY_DEV_BASE_URL    — Dev Sentry base URL (optional; e.g. https://sentry.dev.pfct.io)
"""

import json
import os
import re
import sys
import urllib.error
import urllib.request
from typing import Any, Dict, List, Optional


def parse_issue_id(arg: str) -> str:
    """Extract numeric issue ID from URL or return as-is if already numeric."""
    # Try to extract from URL: /issues/12345/
    match = re.search(r"/issues/(\d+)", arg)
    if match:
        return match.group(1)
    # Accept plain numeric ID
    if re.fullmatch(r"\d+", arg.strip()):
        return arg.strip()
    print(f"ERROR: Cannot parse issue ID from: {arg}", file=sys.stderr)
    sys.exit(1)


def get_env(hint_url: str = "") -> tuple[str, str]:
    """Read required environment variables.

    If ``hint_url`` matches ``SENTRY_DEV_BASE_URL`` host, use the dev token/URL pair.
    Otherwise fall back to the default ``SENTRY_AUTH_TOKEN`` / ``SENTRY_BASE_URL``.
    """
    dev_base = os.environ.get("SENTRY_DEV_BASE_URL", "").rstrip("/")
    dev_token = os.environ.get("SENTRY_DEV_AUTH_TOKEN", "")
    if hint_url and dev_base and dev_token:
        dev_host = re.sub(r"^https?://", "", dev_base).split("/", 1)[0]
        if dev_host and dev_host in hint_url:
            return dev_token, dev_base

    token = os.environ.get("SENTRY_AUTH_TOKEN", "")
    base_url = os.environ.get("SENTRY_BASE_URL", "").rstrip("/")
    if not token:
        print("ERROR: SENTRY_AUTH_TOKEN is not set", file=sys.stderr)
        sys.exit(1)
    if not base_url:
        print("ERROR: SENTRY_BASE_URL is not set", file=sys.stderr)
        sys.exit(1)
    return token, base_url


def sentry_get(url: str, token: str) -> Any:
    """Make authenticated GET request to Sentry API. Returns parsed JSON."""
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 401:
            print("ERROR: Authentication failed (401). Check SENTRY_AUTH_TOKEN.", file=sys.stderr)
        elif e.code == 404:
            print(f"ERROR: Resource not found (404): {url}", file=sys.stderr)
        else:
            body = e.read().decode("utf-8", errors="replace")
            print(f"ERROR: HTTP {e.code} for {url}: {body[:200]}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"ERROR: Network error fetching {url}: {e.reason}", file=sys.stderr)
        sys.exit(1)


def extract_event_data(event: Dict) -> Dict:
    """Extract exception, stacktrace, message, and tags from a Sentry event."""
    exception_info: Optional[Dict] = None
    stacktrace_frames: List[Dict] = []
    message: Optional[str] = None

    entries = event.get("entries", [])
    for entry in entries:
        entry_type = entry.get("type", "")
        data = entry.get("data", {})

        if entry_type == "message":
            # Message entry
            msg = data.get("message") or data.get("formatted", "")
            if msg:
                message = msg

        elif entry_type == "exception":
            # Exception entry — may have multiple values; pick the last (outermost)
            values = data.get("values") or []
            for exc in reversed(values):
                exc_type = exc.get("type")
                exc_value = exc.get("value")
                exc_module = exc.get("module")
                if exc_type or exc_value:
                    exception_info = {
                        "type": exc_type,
                        "value": exc_value,
                        "module": exc_module,
                    }
                # Extract in-app frames from this exception's stacktrace
                raw_st = exc.get("stacktrace") or {}
                frames = raw_st.get("frames") or []
                in_app_frames = [
                    {
                        "file": f.get("filename"),
                        "function": f.get("function"),
                        "line": f.get("lineNo"),
                        "module": f.get("module"),
                        "inApp": True,
                    }
                    for f in frames
                    if f.get("inApp") is True
                ]
                if in_app_frames:
                    stacktrace_frames = in_app_frames
                break  # use the first (outermost) exception with data

    # Tags: event.tags is a list of {"key": ..., "value": ...}
    tags_raw = event.get("tags") or []
    tags: Dict[str, str] = {}
    for tag in tags_raw:
        k = tag.get("key")
        v = tag.get("value")
        if k is not None:
            tags[k] = v

    return {
        "exception": exception_info,
        "stacktrace": stacktrace_frames,
        "message": message,
        "tags": tags,
    }


def fetch_issue(issue_id: str, token: str, base_url: str) -> Dict:
    """Fetch issue metadata from Sentry."""
    url = f"{base_url}/api/0/issues/{issue_id}/"
    return sentry_get(url, token)


def fetch_latest_event(issue_id: str, token: str, base_url: str) -> Dict:
    """Fetch the latest event for an issue."""
    url = f"{base_url}/api/0/issues/{issue_id}/events/latest/"
    return sentry_get(url, token)


def fetch_deep_data(issue_id: str, token: str, base_url: str) -> Dict:
    """Fetch last 10 events + tag distribution for deep mode."""
    events_url = f"{base_url}/api/0/issues/{issue_id}/events/?limit=10"
    events = sentry_get(events_url, token)

    # Unique exception values across events
    # Events list endpoint returns metadata (not full entries), so use metadata.value
    unique_errors: List[str] = []
    seen: set = set()
    for ev in events:
        # Try metadata.value first (events list API)
        meta = ev.get("metadata") or {}
        val = meta.get("value") or ev.get("title") or ev.get("message")
        if val and val not in seen:
            seen.add(val)
            unique_errors.append(val)

    # Tag distribution for key tags
    tag_keys = ["environment", "server_name", "logger", "runtime"]
    tag_distribution: Dict[str, Dict[str, int]] = {}
    for key in tag_keys:
        tag_url = f"{base_url}/api/0/issues/{issue_id}/tags/{key}/"
        try:
            tag_data = sentry_get(tag_url, token)
            top_values = tag_data.get("topValues") or []
            distribution: Dict[str, int] = {}
            for tv in top_values:
                name = tv.get("name") or tv.get("value")
                count = tv.get("count", 0)
                if name is not None:
                    distribution[name] = count
            if distribution:
                tag_distribution[key] = distribution
        except SystemExit:
            # Tag not found or error — skip silently
            pass

    return {
        "events_count": len(events),
        "unique_errors": unique_errors,
        "tag_distribution": tag_distribution,
    }


def build_issue_summary(issue: Dict) -> Dict:
    """Extract relevant fields from issue metadata."""
    return {
        "id": issue.get("id"),
        "title": issue.get("title"),
        "project": (issue.get("project") or {}).get("slug"),
        "platform": (issue.get("project") or {}).get("platform"),
        "count": issue.get("count"),
        "firstSeen": issue.get("firstSeen"),
        "lastSeen": issue.get("lastSeen"),
        "status": issue.get("status"),
        "substatus": issue.get("substatus"),
        "level": issue.get("level"),
        "priority": issue.get("priority"),
    }


def main() -> None:
    args = sys.argv[1:]
    if not args:
        print("Usage: sentry-fetch.py <issue_id_or_url> [--deep]", file=sys.stderr)
        sys.exit(1)

    deep_mode = "--deep" in args
    positional = [a for a in args if not a.startswith("--")]
    if not positional:
        print("ERROR: No issue ID or URL provided.", file=sys.stderr)
        sys.exit(1)

    issue_id = parse_issue_id(positional[0])
    token, base_url = get_env(hint_url=positional[0])

    # Fetch issue metadata
    issue_raw = fetch_issue(issue_id, token, base_url)
    issue_summary = build_issue_summary(issue_raw)

    # Fetch latest event
    latest_event = fetch_latest_event(issue_id, token, base_url)
    event_data = extract_event_data(latest_event)

    # Fetch deep data if requested
    deep_data = None
    if deep_mode:
        deep_data = fetch_deep_data(issue_id, token, base_url)

    output = {
        "issue": issue_summary,
        "exception": event_data["exception"],
        "stacktrace": event_data["stacktrace"],
        "message": event_data["message"],
        "tags": event_data["tags"],
        "deep": deep_data,
    }

    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

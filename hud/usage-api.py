#!/usr/bin/env python3

import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Optional


OAUTH_CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
TOKEN_ENDPOINT = "https://platform.claude.com/v1/oauth/token"
USAGE_ENDPOINT = "https://api.anthropic.com/api/oauth/usage"
CACHE_PATH = Path.home() / ".agmo" / "state" / "usage-cache.json"
REQUEST_TIMEOUT = 10


def get_credentials() -> Optional[dict]:
    config_dir = os.environ.get("CLAUDE_CONFIG_DIR", "")

    if sys.platform == "darwin":
        if config_dir:
            suffix = hashlib.sha256(config_dir.encode()).hexdigest()[:8]
            service_name = f"Claude Code-credentials-{suffix}"
        else:
            service_name = "Claude Code-credentials"

        try:
            result = subprocess.run(
                ["/usr/bin/security", "find-generic-password", "-s", service_name, "-w"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if result.returncode == 0 and result.stdout.strip():
                raw = json.loads(result.stdout.strip())
                return _normalize_credentials(raw)
        except Exception as e:
            print(f"Keychain read failed: {e}", file=sys.stderr)

    credentials_path = (
        Path(config_dir) / ".credentials.json"
        if config_dir
        else Path.home() / ".claude" / ".credentials.json"
    )

    try:
        with open(credentials_path) as f:
            raw = json.load(f)
            return _normalize_credentials(raw)
    except Exception as e:
        print(f"Credentials file read failed: {e}", file=sys.stderr)

    return None


def _normalize_credentials(raw: dict) -> dict:
    if "claudeAiOauth" in raw:
        return raw["claudeAiOauth"]
    return raw


def refresh_token(refresh_tok: str) -> Optional[str]:
    body = urllib.parse.urlencode({
        "grant_type": "refresh_token",
        "refresh_token": refresh_tok,
        "client_id": OAUTH_CLIENT_ID,
    }).encode()

    req = urllib.request.Request(
        TOKEN_ENDPOINT,
        data=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            data = json.loads(resp.read())
            return data.get("access_token")
    except Exception as e:
        print(f"Token refresh failed: {e}", file=sys.stderr)
        return None


def fetch_usage(access_token: str) -> dict:
    req = urllib.request.Request(
        USAGE_ENDPOINT,
        headers={
            "Authorization": f"Bearer {access_token}",
            "anthropic-beta": "oauth-2025-04-20",
            "Content-Type": "application/json",
        },
        method="GET",
    )

    with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
        return json.loads(resp.read())


def read_cache() -> Optional[dict]:
    try:
        with open(CACHE_PATH) as f:
            return json.load(f)
    except Exception:
        return None


def write_cache(
    data: Any, is_error: bool, is_network_error: bool = False, last_success_at: Optional[int] = None
) -> None:
    try:
        CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
        now_ms = int(time.time() * 1000)
        cache = {
            "timestamp": now_ms,
            "data": data,
            "error": is_error,
            "network_error": is_network_error,
            "last_success_at": last_success_at if last_success_at is not None else (now_ms if not is_error else None),
        }
        with open(CACHE_PATH, "w") as f:
            json.dump(cache, f)
    except Exception as e:
        print(f"Cache write failed: {e}", file=sys.stderr)


def _cache_ttl(cache: dict, is_network_error: bool) -> int:
    if cache.get("error"):
        return 120_000 if is_network_error else 15_000
    return 90_000


def _cache_is_valid(cache: dict) -> bool:
    now_ms = int(time.time() * 1000)
    age = now_ms - cache.get("timestamp", 0)
    return age < _cache_ttl(cache, cache.get("network_error", False))


def _stale_cache_usable(cache: dict) -> bool:
    last_success = cache.get("last_success_at")
    if not last_success:
        return False
    now_ms = int(time.time() * 1000)
    return (now_ms - last_success) < 15 * 60 * 1000


def format_reset_time(resets_at: str) -> str:
    try:
        import datetime
        reset_dt = datetime.datetime.fromisoformat(resets_at.replace("Z", "+00:00"))
        now_dt = datetime.datetime.now(datetime.timezone.utc)
        diff = reset_dt - now_dt
        total_seconds = int(diff.total_seconds())

        if total_seconds <= 0:
            return "0m"

        if total_seconds < 3600:
            return f"{total_seconds // 60}m"

        if total_seconds < 86400:
            h = total_seconds // 3600
            m = (total_seconds % 3600) // 60
            return f"{h}h{m}m"

        d = total_seconds // 86400
        h = (total_seconds % 86400) // 3600
        return f"{d}d{h}h"
    except Exception as e:
        print(f"format_reset_time error: {e}", file=sys.stderr)
        return "?"


def _build_output(data: dict) -> dict:
    five_hour = data.get("five_hour", {})
    seven_day = data.get("seven_day", {})

    five_util = five_hour.get("utilization", 0) or 0
    seven_util = seven_day.get("utilization", 0) or 0
    # API returns 0-1 fraction or 0-100 percentage; normalize to 0-100
    five_pct = five_util * 100 if five_util <= 1 else five_util
    seven_pct = seven_util * 100 if seven_util <= 1 else seven_util

    return {
        "5h_pct": round(min(five_pct, 100)),
        "5h_reset": format_reset_time(five_hour.get("resets_at", "")),
        "wk_pct": round(min(seven_pct, 100)),
        "wk_reset": format_reset_time(seven_day.get("resets_at", "")),
    }


def main() -> None:
    now_ms = int(time.time() * 1000)
    cache = read_cache()

    if cache and _cache_is_valid(cache):
        if cache.get("error"):
            if _stale_cache_usable(cache) and cache.get("data"):
                print(json.dumps(_build_output(cache["data"])))
            else:
                print(json.dumps({"error": True}))
            return
        print(json.dumps(_build_output(cache["data"])))
        return

    creds = get_credentials()
    if not creds:
        if cache and _stale_cache_usable(cache) and not cache.get("error"):
            print(json.dumps(_build_output(cache["data"])))
        else:
            print(json.dumps({"error": True}))
        return

    access_token = creds.get("accessToken")
    expires_at = creds.get("expiresAt", 0)

    if expires_at and expires_at <= now_ms:
        refresh_tok = creds.get("refreshToken")
        if refresh_tok:
            new_token = refresh_token(refresh_tok)
            if new_token:
                access_token = new_token
            else:
                print("Token refresh failed, using existing token", file=sys.stderr)

    if not access_token:
        if cache and _stale_cache_usable(cache) and not cache.get("error"):
            print(json.dumps(_build_output(cache["data"])))
        else:
            print(json.dumps({"error": True}))
        return

    last_success_at = cache.get("last_success_at") if cache else None

    try:
        data = fetch_usage(access_token)
        write_cache(data, is_error=False)
        print(json.dumps(_build_output(data)))
    except urllib.error.URLError as e:
        print(f"Network error fetching usage: {e}", file=sys.stderr)
        write_cache(None, is_error=True, is_network_error=True, last_success_at=last_success_at)
        if cache and _stale_cache_usable(cache) and not cache.get("error"):
            print(json.dumps(_build_output(cache["data"])))
        else:
            print(json.dumps({"error": True}))
    except Exception as e:
        print(f"Error fetching usage: {e}", file=sys.stderr)
        write_cache(None, is_error=True, is_network_error=False, last_success_at=last_success_at)
        if cache and _stale_cache_usable(cache) and not cache.get("error"):
            print(json.dumps(_build_output(cache["data"])))
        else:
            print(json.dumps({"error": True}))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Decap/Sveltia-compatible GitHub OAuth proxy (authorization-code → popup postMessage)."""

from __future__ import annotations

import json
import os
import re
import secrets
import urllib.error
import urllib.parse
import urllib.request
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

SUPPORTED = {"github"}
GITHUB_SCOPES_DEFAULT = "repo,user"
GITHUB_SCOPES_ALLOWED = {"repo", "public_repo", "user", "read:user", "user:email"}


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


def domain_patterns(allowed: str) -> list[str]:
    patterns: list[str] = []
    for part in allowed.split(","):
        host = part.strip()
        if not host:
            continue
        escaped = re.escape(host).replace(r"\*", ".+")
        patterns.append(f"^{escaped}$")
    return patterns


def scope_for(requested: str | None) -> str:
    scopes = [s for s in re.split(r"[\s,]+", requested or "") if s]
    if not scopes:
        return GITHUB_SCOPES_DEFAULT
    if all(s in GITHUB_SCOPES_ALLOWED for s in scopes):
        return ",".join(scopes)
    return GITHUB_SCOPES_DEFAULT


def matches_domain(hostname: str | None, patterns: list[str]) -> bool:
    if not patterns:
        return True
    if not hostname:
        return False
    return any(re.search(p, hostname) is not None for p in patterns)


def serialize_js(value: Any) -> str:
    return json.dumps(value).replace("<", "\\u003c")


def output_html(
    *,
    provider: str = "unknown",
    token: str | None = None,
    error: str | None = None,
    error_code: str | None = None,
    allowed_domains: str = "",
) -> tuple[int, dict[str, str], bytes]:
    state = "error" if error else "success"
    content: dict[str, Any] = (
        {"provider": provider, "error": error, "errorCode": error_code}
        if error
        else {"provider": provider, "token": token}
    )
    body = f"""<!doctype html><html><body><script>
(() => {{
  const trustedPatterns = {serialize_js(domain_patterns(allowed_domains))};
  const hasToken = {serialize_js(bool(token))};
  const isTrusted = (origin) => {{
    try {{
      const {{ hostname }} = new URL(origin);
      return trustedPatterns.some((pattern) => new RegExp(pattern).test(hostname));
    }} catch {{
      return false;
    }}
  }};
  window.addEventListener('message', ({{ data, origin }}) => {{
    if (data !== 'authorizing:{provider}') return;
    if (hasToken && trustedPatterns.length && !isTrusted(origin)) return;
    window.opener?.postMessage(
      'authorization:{provider}:{state}:{json.dumps(content)}',
      origin
    );
  }});
  window.opener?.postMessage('authorizing:{provider}', '*');
}})();
</script></body></html>
"""
    headers = {
        "Content-Type": "text/html;charset=UTF-8",
        "Set-Cookie": "csrf-token=deleted; HttpOnly; Max-Age=0; Path=/; SameSite=Lax; Secure",
    }
    return 200, headers, body.encode()


class Handler(BaseHTTPRequestHandler):
    server_version = "cms-oauth/1"

    def log_message(self, fmt: str, *args: Any) -> None:
        # Avoid logging query strings (may contain codes).
        sys_stderr = __import__("sys").stderr
        print("%s - %s" % (self.address_string(), fmt % args), file=sys_stderr)

    def _origin(self) -> str:
        host = self.headers.get("X-Forwarded-Host") or self.headers.get("Host") or "localhost"
        proto = self.headers.get("X-Forwarded-Proto") or "https"
        return f"{proto}://{host}"

    def _send(self, status: int, headers: dict[str, str], body: bytes) -> None:
        self.send_response(status)
        for k, v in headers.items():
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        qs = urllib.parse.parse_qs(parsed.query)

        if path in ("/auth", "/oauth/authorize"):
            self._auth(qs)
            return
        if path in ("/callback", "/oauth/redirect"):
            self._callback(qs)
            return
        self._send(404, {"Content-Type": "text/plain"}, b"Not Found")

    def _auth(self, qs: dict[str, list[str]]) -> None:
        allowed = _env("ALLOWED_DOMAINS")
        provider = (qs.get("provider") or [""])[0]
        site_id = (qs.get("site_id") or [""])[0]
        requested_scope = (qs.get("scope") or [None])[0]

        if provider not in SUPPORTED:
            status, headers, body = output_html(
                allowed_domains=allowed,
                error="Your Git backend is not supported by the authenticator.",
                error_code="UNSUPPORTED_BACKEND",
            )
            self._send(status, headers, body)
            return

        patterns = domain_patterns(allowed)
        if patterns and not matches_domain(site_id or None, patterns):
            status, headers, body = output_html(
                provider=provider,
                allowed_domains=allowed,
                error="Your domain is not allowed to use the authenticator.",
                error_code="UNSUPPORTED_DOMAIN",
            )
            self._send(status, headers, body)
            return

        client_id = _env("GITHUB_CLIENT_ID")
        client_secret = _env("GITHUB_CLIENT_SECRET")
        if not client_id or not client_secret:
            status, headers, body = output_html(
                provider=provider,
                allowed_domains=allowed,
                error="OAuth app client ID or secret is not configured.",
                error_code="MISCONFIGURED_CLIENT",
            )
            self._send(status, headers, body)
            return

        csrf = secrets.token_hex(16)
        gh_host = _env("GITHUB_HOSTNAME", "github.com")
        params = urllib.parse.urlencode(
            {
                "client_id": client_id,
                "scope": scope_for(requested_scope),
                "state": csrf,
            }
        )
        location = f"https://{gh_host}/login/oauth/authorize?{params}"
        cookie = (
            f"csrf-token={provider}_{csrf}; HttpOnly; Path=/; Max-Age=600; SameSite=Lax; Secure"
        )
        self.send_response(302)
        self.send_header("Location", location)
        self.send_header("Set-Cookie", cookie)
        self.end_headers()

    def _callback(self, qs: dict[str, list[str]]) -> None:
        allowed = _env("ALLOWED_DOMAINS")
        code = (qs.get("code") or [""])[0]
        state = (qs.get("state") or [""])[0]

        cookie_header = self.headers.get("Cookie", "")
        jar = SimpleCookie()
        jar.load(cookie_header)
        raw = jar["csrf-token"].value if "csrf-token" in jar else ""
        m = re.match(r"^([a-z-]+)_([0-9a-f]{32})$", raw)
        provider = m.group(1) if m else ""
        csrf = m.group(2) if m else ""

        if provider not in SUPPORTED:
            status, headers, body = output_html(
                allowed_domains=allowed,
                error="Your Git backend is not supported by the authenticator.",
                error_code="UNSUPPORTED_BACKEND",
            )
            self._send(status, headers, body)
            return

        if not code or not state:
            status, headers, body = output_html(
                provider=provider,
                allowed_domains=allowed,
                error="Failed to receive an authorization code. Please try again later.",
                error_code="AUTH_CODE_REQUEST_FAILED",
            )
            self._send(status, headers, body)
            return

        if not csrf or state != csrf:
            status, headers, body = output_html(
                provider=provider,
                allowed_domains=allowed,
                error="Potential CSRF attack detected. Authentication flow aborted.",
                error_code="CSRF_DETECTED",
            )
            self._send(status, headers, body)
            return

        client_id = _env("GITHUB_CLIENT_ID")
        client_secret = _env("GITHUB_CLIENT_SECRET")
        if not client_id or not client_secret:
            status, headers, body = output_html(
                provider=provider,
                allowed_domains=allowed,
                error="OAuth app client ID or secret is not configured.",
                error_code="MISCONFIGURED_CLIENT",
            )
            self._send(status, headers, body)
            return

        gh_host = _env("GITHUB_HOSTNAME", "github.com")
        token_url = f"https://{gh_host}/login/oauth/access_token"
        payload = json.dumps(
            {
                "code": code,
                "client_id": client_id,
                "client_secret": client_secret,
            }
        ).encode()
        req = urllib.request.Request(
            token_url,
            data=payload,
            headers={
                "Accept": "application/json",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode())
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
            status, headers, body = output_html(
                provider=provider,
                allowed_domains=allowed,
                error="Failed to request an access token. Please try again later.",
                error_code="TOKEN_REQUEST_FAILED",
            )
            self._send(status, headers, body)
            return

        token = data.get("access_token")
        err = data.get("error")
        status, headers, body = output_html(
            provider=provider,
            token=token,
            error=err,
            allowed_domains=allowed,
        )
        self._send(status, headers, body)


def main() -> None:
    port = int(_env("PORT", "8080") or "8080")
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"cms-oauth listening on :{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()

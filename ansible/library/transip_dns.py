#!/usr/bin/python
from __future__ import annotations

DOCUMENTATION = r"""
module: transip_dns
short_description: Converge TransIP DNS record sets
description:
  - Each record set (domain + name + type) is made to hold exactly the given
    contents and expire. Entries with other name/type pairs are left alone.
  - New entries are added before stale ones are removed, so a changed A/AAAA
    never resolves to nothing.
options:
  account_name:
    description: TransIP account (login) name.
    required: true
    type: str
  private_key:
    description: TransIP API private key (PEM).
    required: true
    type: str
  records:
    description: Record sets to converge.
    required: true
    type: list
    elements: dict
    suboptions:
      domain: {type: str, required: true}
      name: {type: str, required: true}
      type: {type: str, required: true}
      expire: {type: int, required: true}
      content: {type: list, elements: str, required: true}
"""

import base64
import json
import secrets
import urllib.error
import urllib.parse
import urllib.request

from ansible.module_utils.basic import AnsibleModule

API = "https://api.transip.nl/v6"


def _request(method, path, token, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(API + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"{method} {path}: HTTP {exc.code} {exc.read().decode(errors='replace')}") from exc
    return json.loads(raw) if raw else {}


def _token(account_name, private_key):
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import padding

    nonce = secrets.token_hex(16)
    body = {
        "login": account_name,
        "nonce": nonce,
        "read_only": False,
        "expiration_time": "30 minutes",
        "label": "iac-" + nonce,
        "global_key": True,
    }
    payload = json.dumps(body).encode()
    key = serialization.load_pem_private_key(private_key.encode(), password=None)
    signature = base64.b64encode(key.sign(payload, padding.PKCS1v15(), hashes.SHA512())).decode()
    req = urllib.request.Request(API + "/auth", data=payload, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Signature", signature)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read())["token"]
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"TransIP auth: HTTP {exc.code} {exc.read().decode(errors='replace')}") from exc


def main():
    module = AnsibleModule(
        argument_spec={
            "account_name": {"type": "str", "required": True},
            "private_key": {"type": "str", "required": True, "no_log": True},
            "records": {"type": "list", "elements": "dict", "required": True},
        },
        supports_check_mode=True,
    )
    try:
        token = _token(module.params["account_name"], module.params["private_key"])
        domains = sorted({r["domain"] for r in module.params["records"]})
        existing = {
            d: _request("GET", f"/domains/{urllib.parse.quote(d)}/dns", token).get("dnsEntries", [])
            for d in domains
        }

        to_add, to_remove, before, after = [], [], [], []
        for rec in module.params["records"]:
            domain, name, rtype, expire = rec["domain"], rec["name"], rec["type"], int(rec["expire"])
            want = {(c, expire) for c in rec["content"]}
            have = {
                (e["content"], int(e["expire"]))
                for e in existing[domain]
                if e["name"] == name and e["type"] == rtype
            }
            label = f"{name}.{domain} {rtype}"
            before.append(f"{label} {sorted(have)}")
            after.append(f"{label} {sorted(want)}")
            for content, ttl in sorted(want - have):
                to_add.append((domain, {"name": name, "expire": ttl, "type": rtype, "content": content}))
            for content, ttl in sorted(have - want):
                to_remove.append((domain, {"name": name, "expire": ttl, "type": rtype, "content": content}))

        changed = bool(to_add or to_remove)
        if changed and not module.check_mode:
            for domain, entry in to_add:
                _request("POST", f"/domains/{urllib.parse.quote(domain)}/dns", token, {"dnsEntry": entry})
            for domain, entry in to_remove:
                _request("DELETE", f"/domains/{urllib.parse.quote(domain)}/dns", token, {"dnsEntry": entry})
    except Exception as exc:  # noqa: BLE001
        module.fail_json(msg=str(exc))

    added = [f"{e['name']}.{d} {e['type']} {e['content']}" for d, e in to_add]
    removed = [f"{e['name']}.{d} {e['type']} {e['content']}" for d, e in to_remove]
    module.exit_json(
        changed=changed,
        msg=f"added: {', '.join(added) or '-'}; removed: {', '.join(removed) or '-'}" if changed else "",
        added=added,
        removed=removed,
        diff={"before": "\n".join(before) + "\n", "after": "\n".join(after) + "\n"},
    )


if __name__ == "__main__":
    main()

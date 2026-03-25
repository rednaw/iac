# DNS records and DNSSEC for the platform.
#
# TransIP is both registrar and DNS provider — no zone creation needed.
# Record ownership: each workspace manages records pointing to its own server.
# DNSSEC is managed via transip_domain_dnssec (prod only).

locals {
  is_prod     = local.environment == "prod"
  is_dev      = local.environment == "dev"
  server_ipv6 = hcloud_server.platform.ipv6_address
}

# ──────────────────────────────────────────────
# Dev records (destroyed with dev server)
# ──────────────────────────────────────────────

resource "transip_dns_record" "dev_a" {
  count   = local.is_dev ? 1 : 0
  domain  = var.base_domain
  name    = "dev"
  type    = "A"
  expire  = 300
  content = [hcloud_server.platform.ipv4_address]
}

resource "transip_dns_record" "dev_aaaa" {
  count   = local.is_dev ? 1 : 0
  domain  = var.base_domain
  name    = "dev"
  type    = "AAAA"
  expire  = 300
  content = [local.server_ipv6]
}

# ──────────────────────────────────────────────
# Prod server records
# ──────────────────────────────────────────────

resource "transip_dns_record" "prod_a" {
  count   = local.is_prod ? 1 : 0
  domain  = var.base_domain
  name    = "prod"
  type    = "A"
  expire  = 60
  content = [hcloud_server.platform.ipv4_address]
}

resource "transip_dns_record" "prod_aaaa" {
  count   = local.is_prod ? 1 : 0
  domain  = var.base_domain
  name    = "prod"
  type    = "AAAA"
  expire  = 60
  content = [local.server_ipv6]
}

resource "transip_dns_record" "apex_a" {
  count   = local.is_prod ? 1 : 0
  domain  = var.base_domain
  name    = "@"
  type    = "A"
  expire  = 60
  content = [hcloud_server.platform.ipv4_address]
}

resource "transip_dns_record" "apex_aaaa" {
  count   = local.is_prod ? 1 : 0
  domain  = var.base_domain
  name    = "@"
  type    = "AAAA"
  expire  = 60
  content = [local.server_ipv6]
}

resource "transip_dns_record" "registry_a" {
  count   = local.is_prod ? 1 : 0
  domain  = var.base_domain
  name    = "registry"
  type    = "A"
  expire  = 60
  content = [hcloud_server.platform.ipv4_address]
}

resource "transip_dns_record" "registry_aaaa" {
  count   = local.is_prod ? 1 : 0
  domain  = var.base_domain
  name    = "registry"
  type    = "AAAA"
  expire  = 60
  content = [local.server_ipv6]
}

resource "transip_dns_record" "www" {
  count   = local.is_prod ? 1 : 0
  domain  = var.base_domain
  name    = "www"
  type    = "CNAME"
  expire  = 60
  content = ["prod.${var.base_domain}."]
}

# ──────────────────────────────────────────────
# Email anti-spoofing (domain does not handle email)
# ──────────────────────────────────────────────

resource "transip_dns_record" "null_mx" {
  count   = local.is_prod ? 1 : 0
  domain  = var.base_domain
  name    = "@"
  type    = "MX"
  expire  = 86400
  content = ["0 ."]
}

resource "transip_dns_record" "apex_spf" {
  count   = local.is_prod ? 1 : 0
  domain  = var.base_domain
  name    = "@"
  type    = "TXT"
  expire  = 86400
  content = ["v=spf1 -all"]
}

resource "transip_dns_record" "dmarc" {
  count   = local.is_prod ? 1 : 0
  domain  = var.base_domain
  name    = "_dmarc"
  type    = "TXT"
  expire  = 86400
  content = ["v=DMARC1; p=reject;"]
}

# ──────────────────────────────────────────────
# DNSSEC (prod only — applies to the whole domain)
# ──────────────────────────────────────────────
#
# transip_domain_dnssec requires at least 1 dnssec {} block with real key material
# (key_tag, flags, algorithm, public_key) from TransIP's authoritative servers.
#
# To add DNSSEC management:
#   1. Enable DNSSEC at https://www.transip.eu/cp/domein/ (or confirm it is already active)
#   2. Retrieve the key material from the TransIP API or control panel
#   3. Add a transip_domain_dnssec resource block with the actual values and apply
#
# resource "transip_domain_dnssec" "main" {
#   count  = local.is_prod ? 1 : 0
#   domain = var.base_domain
#
#   dnssec {
#     key_tag    = <key_tag>   # 5-digit value from TransIP
#     flags      = 257         # 256 = ZSK, 257 = KSK
#     algorithm  = 13          # ECDSA-P256-SHA256
#     public_key = "<base64>"
#   }
# }

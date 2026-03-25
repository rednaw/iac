# DNS zone and records for the platform.
#
# Zone ownership: prod creates the zone, dev looks it up as a data source.
# Record ownership: each workspace manages records pointing to its own server.
# Consequence: terraform apply -- prod must run before terraform apply -- dev.

locals {
  is_prod     = local.environment == "prod"
  is_dev      = local.environment == "dev"
  zone        = local.is_prod ? hcloud_zone.main[0].name : data.hcloud_zone.main[0].name
  server_ipv6 = hcloud_server.platform.ipv6_address
}

# ──────────────────────────────────────────────
# Zone
# ──────────────────────────────────────────────

resource "hcloud_zone" "main" {
  count = local.is_prod ? 1 : 0
  name  = var.base_domain
  mode  = "primary"
}

data "hcloud_zone" "main" {
  count = local.is_dev ? 1 : 0
  name  = var.base_domain
}

# ──────────────────────────────────────────────
# Dev records (destroyed with dev server)
# ──────────────────────────────────────────────

resource "hcloud_zone_rrset" "dev_a" {
  count   = local.is_dev ? 1 : 0
  zone    = local.zone
  name    = "dev"
  type    = "A"
  ttl     = 300
  records = [{ value = hcloud_server.platform.ipv4_address }]
}

resource "hcloud_zone_rrset" "dev_aaaa" {
  count   = local.is_dev ? 1 : 0
  zone    = local.zone
  name    = "dev"
  type    = "AAAA"
  ttl     = 300
  records = [{ value = local.server_ipv6 }]
}

# ──────────────────────────────────────────────
# Prod server records
# ──────────────────────────────────────────────

resource "hcloud_zone_rrset" "prod_a" {
  count   = local.is_prod ? 1 : 0
  zone    = local.zone
  name    = "prod"
  type    = "A"
  ttl     = 60
  records = [{ value = hcloud_server.platform.ipv4_address }]
}

resource "hcloud_zone_rrset" "prod_aaaa" {
  count   = local.is_prod ? 1 : 0
  zone    = local.zone
  name    = "prod"
  type    = "AAAA"
  ttl     = 60
  records = [{ value = local.server_ipv6 }]
}

resource "hcloud_zone_rrset" "apex_a" {
  count   = local.is_prod ? 1 : 0
  zone    = local.zone
  name    = "@"
  type    = "A"
  ttl     = 60
  records = [{ value = hcloud_server.platform.ipv4_address }]
}

resource "hcloud_zone_rrset" "apex_aaaa" {
  count   = local.is_prod ? 1 : 0
  zone    = local.zone
  name    = "@"
  type    = "AAAA"
  ttl     = 60
  records = [{ value = local.server_ipv6 }]
}

resource "hcloud_zone_rrset" "registry_a" {
  count   = local.is_prod ? 1 : 0
  zone    = local.zone
  name    = "registry"
  type    = "A"
  ttl     = 60
  records = [{ value = hcloud_server.platform.ipv4_address }]
}

resource "hcloud_zone_rrset" "registry_aaaa" {
  count   = local.is_prod ? 1 : 0
  zone    = local.zone
  name    = "registry"
  type    = "AAAA"
  ttl     = 60
  records = [{ value = local.server_ipv6 }]
}

resource "hcloud_zone_rrset" "www" {
  count   = local.is_prod ? 1 : 0
  zone    = local.zone
  name    = "www"
  type    = "CNAME"
  ttl     = 60
  records = [{ value = "prod.${var.base_domain}." }]
}

# ──────────────────────────────────────────────
# Email anti-spoofing (domain does not handle email)
# ──────────────────────────────────────────────

resource "hcloud_zone_rrset" "null_mx" {
  count   = local.is_prod ? 1 : 0
  zone    = local.zone
  name    = "@"
  type    = "MX"
  ttl     = 86400
  records = [{ value = "0 ." }]
}

resource "hcloud_zone_rrset" "apex_spf" {
  count   = local.is_prod ? 1 : 0
  zone    = local.zone
  name    = "@"
  type    = "TXT"
  ttl     = 86400
  records = [{ value = "\"v=spf1 -all\"" }]
}

resource "hcloud_zone_rrset" "dmarc" {
  count   = local.is_prod ? 1 : 0
  zone    = local.zone
  name    = "_dmarc"
  type    = "TXT"
  ttl     = 86400
  records = [{ value = "\"v=DMARC1; p=reject;\"" }]
}

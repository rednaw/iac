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
  expire  = 60
  content = [hcloud_server.platform.ipv4_address]
}

resource "transip_dns_record" "dev_aaaa" {
  count   = local.is_dev ? 1 : 0
  domain  = var.base_domain
  name    = "dev"
  type    = "AAAA"
  expire  = 60
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
  depends_on = [
    transip_dns_record.prod_a,
    transip_dns_record.prod_aaaa,
  ]
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

# DNSSEC is managed by TransIP defaults/policy outside Terraform.

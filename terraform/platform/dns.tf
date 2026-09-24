# DNS records and DNSSEC for the platform.
#
# TransIP is both registrar and DNS provider — no zone creation needed.
# Records point at this single platform server. DNSSEC is managed by TransIP
# defaults/policy outside Terraform.
#
# No platform hostname on base_domain (SSH/Ansible use API IPv4). App apex/www
# live on site_domain. Other app subdomains (e.g. prod.) have no records.

locals {
  server_ipv4 = module.server.ipv4_address
  server_ipv6 = module.server.ipv6_address
  site_domain = coalesce(var.app_domain, var.base_domain)
  dns_split   = var.app_domain != "" && var.app_domain != var.base_domain
}

# ──────────────────────────────────────────────
# Site + platform service records
# ──────────────────────────────────────────────

resource "transip_dns_record" "apex_a" {
  domain  = local.site_domain
  name    = "@"
  type    = "A"
  expire  = 60
  content = [local.server_ipv4]
}

resource "transip_dns_record" "apex_aaaa" {
  domain  = local.site_domain
  name    = "@"
  type    = "AAAA"
  expire  = 60
  content = [local.server_ipv6]
}

resource "transip_dns_record" "registry_a" {
  domain  = var.base_domain
  name    = "registry"
  type    = "A"
  expire  = 60
  content = [local.server_ipv4]
}

resource "transip_dns_record" "registry_aaaa" {
  domain  = var.base_domain
  name    = "registry"
  type    = "AAAA"
  expire  = 60
  content = [local.server_ipv6]
}

resource "transip_dns_record" "auth_a" {
  domain  = var.base_domain
  name    = "auth"
  type    = "A"
  expire  = 60
  content = [local.server_ipv4]
}

resource "transip_dns_record" "auth_aaaa" {
  domain  = var.base_domain
  name    = "auth"
  type    = "AAAA"
  expire  = 60
  content = [local.server_ipv6]
}

resource "transip_dns_record" "www" {
  domain  = local.site_domain
  name    = "www"
  type    = "CNAME"
  expire  = 60
  content = ["${local.site_domain}."]
  depends_on = [
    transip_dns_record.apex_a,
    transip_dns_record.apex_aaaa,
  ]
}

# ──────────────────────────────────────────────
# Email anti-spoofing (domain does not handle email)
# ──────────────────────────────────────────────

resource "transip_dns_record" "null_mx" {
  domain  = var.base_domain
  name    = "@"
  type    = "MX"
  expire  = 86400
  content = ["0 ."]
}

resource "transip_dns_record" "apex_spf" {
  domain  = var.base_domain
  name    = "@"
  type    = "TXT"
  expire  = 86400
  content = ["v=spf1 -all"]
}

resource "transip_dns_record" "dmarc" {
  domain  = var.base_domain
  name    = "_dmarc"
  type    = "TXT"
  expire  = 86400
  content = ["v=DMARC1; p=reject;"]
}

resource "transip_dns_record" "app_null_mx" {
  count   = local.dns_split ? 1 : 0
  domain  = var.app_domain
  name    = "@"
  type    = "MX"
  expire  = 86400
  content = ["0 ."]
}

resource "transip_dns_record" "app_apex_spf" {
  count   = local.dns_split ? 1 : 0
  domain  = var.app_domain
  name    = "@"
  type    = "TXT"
  expire  = 86400
  content = ["v=spf1 -all"]
}

resource "transip_dns_record" "app_dmarc" {
  count   = local.dns_split ? 1 : 0
  domain  = var.app_domain
  name    = "_dmarc"
  type    = "TXT"
  expire  = 86400
  content = ["v=DMARC1; p=reject;"]
}

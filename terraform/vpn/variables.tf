variable "hcloud_token" {
  description = "Hetzner Cloud API token (same account as platform)"
  type        = string
  sensitive   = true
}

variable "ssh_keys" {
  description = "List of Hetzner Cloud SSH key IDs to authorize on the server"
  type        = list(string)
  sensitive   = true
}

variable "vpn_allowed_ssh_ips" {
  description = "Standing SSH allowlist for the VPN box (home only; never the world, never platform IPs)"
  type        = list(string)
  sensitive   = true
}

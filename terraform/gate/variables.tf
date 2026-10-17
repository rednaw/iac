variable "hcloud_token" {
  description = "Hetzner Cloud API token for Cloud project Gate only (from secrets/gate.yml)"
  type        = string
  sensitive   = true
}

variable "ssh_keys" {
  description = "Hetzner SSH key IDs in project Gate (not Default)"
  type        = list(string)
  sensitive   = true
}

variable "vpn_allowed_ssh_ips" {
  description = "SSH allowlist for the gate box (world only for brief travel bootstrap, then home)"
  type        = list(string)
  sensitive   = true
}

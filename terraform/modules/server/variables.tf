variable "name" {
  description = "Server name (used as hcloud_server.name)"
  type        = string
}

variable "firewall_name" {
  description = "Firewall name. Defaults to {name}-firewall when null."
  type        = string
  default     = null
}

variable "server_type" {
  description = "Hetzner server type (e.g. cx23)."
  type        = string
  default     = "cx23"
}

variable "location" {
  description = "Hetzner datacenter location."
  type        = string
  default     = "nbg1"
}

variable "image" {
  description = "OS image to use."
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_keys" {
  description = "List of Hetzner Cloud SSH key IDs to authorize on the server."
  type        = list(string)
  sensitive   = true
}

variable "allowed_ssh_ips" {
  description = "List of IP addresses or CIDR blocks allowed to SSH (port 22)."
  type        = list(string)
  sensitive   = true
}

variable "additional_firewall_rules" {
  description = <<-EOT
    Extra inbound rules to add on top of the base SSH+ICMP rules. Each rule is
    a hcloud_firewall.rule block. Defaults to source_ips = 0.0.0.0/0 + ::/0.
  EOT
  type = list(object({
    direction       = optional(string, "in")
    protocol        = string
    port            = optional(string)
    source_ips      = optional(list(string), ["0.0.0.0/0", "::/0"])
    destination_ips = optional(list(string))
    description     = string
  }))
  default = []
}

variable "labels" {
  description = "Labels applied to the hcloud_server."
  type        = map(string)
  default     = {}
}

variable "backups" {
  description = "Whether Hetzner backups are enabled on the server."
  type        = bool
  default     = true
}

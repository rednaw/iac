variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "transip_account_name" {
  description = "TransIP API account name"
  type        = string
}

variable "transip_private_key" {
  description = "TransIP API private key (PEM)"
  type        = string
  sensitive   = true
}

variable "ssh_keys" {
  description = "List of Hetzner Cloud SSH key IDs to authorize on the server"
  type        = list(string)
  sensitive   = true
}

variable "allowed_ssh_ips" {
  description = "List of IP addresses or CIDR blocks allowed to SSH"
  type        = list(string)
  sensitive   = true
}

variable "base_domain" {
  description = "Base domain for the platform (e.g. milledoni.com)"
  type        = string
}

variable "server_user" {
  description = "SSH user for Ansible (default ubuntu for normal runs)"
  type        = string
  default     = "ubuntu"
}

variable "server_name" {
  description = "Name of the VPS server (defaults to platform-{environment} if not specified)"
  type        = string
  default     = null
}

variable "server_type" {
  description = "Hetzner server type."
  type        = string
  default     = "cx23" # 2 vCPU, 4GB RAM, 40GB SSD - cheapest option (~€3.49/month)
}

variable "server_location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1" # Nuremberg
}

variable "server_image" {
  description = "OS image to use"
  type        = string
  default     = "ubuntu-24.04"
}

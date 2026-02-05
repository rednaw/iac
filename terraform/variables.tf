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



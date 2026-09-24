terraform {
  required_version = "~> 1.16.0"

  backend "remote" {
    workspaces {
      name = "vpn"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

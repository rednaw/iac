terraform {
  required_version = "~> 1.17.0"

  backend "remote" {
    workspaces {
      name = "gate"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

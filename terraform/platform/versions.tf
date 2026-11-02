terraform {
  required_version = "~> 1.17.0"

  backend "remote" {
    workspaces {
      name = "platform"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    transip = {
      source  = "aequitas/transip"
      version = "~> 0.1"
    }
  }
}

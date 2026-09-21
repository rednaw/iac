terraform {
  required_version = "~> 1.16.0"

  backend "remote" {
    workspaces {
      # Single workspace: vpn-prod (there is no vpn-dev — the box is throwaway,
      # home smoke runs on this same prod box).
      prefix = "vpn-"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

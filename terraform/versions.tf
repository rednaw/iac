terraform {
  required_version = "~> 1.14.0"

  backend "remote" {
    organization = "milledoni"
    workspaces {
      # Workspaces are selected via terraform workspace select command
      # Expected workspaces: giftfinder-dev, giftfinder-prod
      # Use prefix to match all giftfinder workspaces
      prefix = "giftfinder-"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.0"
    }
  }
}


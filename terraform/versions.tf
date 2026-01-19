terraform {
  required_version = "~> 1.5.0"

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
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 0.7"
    }
  }
}


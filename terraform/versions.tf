terraform {
  required_version = "~> 1.14.0"

  backend "remote" {
    workspaces {
      # Workspaces are selected via terraform workspace select command
      # Expected workspaces: platform-dev, platform-prod
      # Use prefix to match all platform workspaces
      prefix = "platform-"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}


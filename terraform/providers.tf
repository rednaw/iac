# Provider configuration
# Uses the hcloud_token from the decrypted SOPS secrets

provider "hcloud" {
  token = local.hcloud_token
}


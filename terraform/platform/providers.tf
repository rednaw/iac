provider "hcloud" {
  token = var.hcloud_token
}

provider "transip" {
  account_name = var.transip_account_name
  private_key  = var.transip_private_key
}

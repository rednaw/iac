locals {
  environment = replace(terraform.workspace, "platform-", "")
  server_name = var.server_name != null ? var.server_name : "${local.project_slug}-${local.environment}"
  project_slug = replace(local.base_domain, ".", "-")

  # Aliases used by providers.tf and outputs.tf
  hcloud_token = var.hcloud_token
  base_domain  = var.base_domain

  # SSH key validation — IDs must be numeric Hetzner key IDs
  ssh_keys_invalid = [
    for key_id in var.ssh_keys :
    key_id if !can(tonumber(key_id))
  ]
  ssh_keys = var.ssh_keys

  # Allowed SSH IP validation — must be valid CIDR or plain IP
  ssh_ips_invalid = [
    for ip in var.allowed_ssh_ips :
    ip if !can(cidrhost(length(regexall("/", ip)) > 0 ? ip : "${ip}/32", 0))
  ]
  allowed_ssh_ips = var.allowed_ssh_ips
}

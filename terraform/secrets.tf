# Read encrypted infrastructure secrets (YAML format)
data "sops_file" "infrastructure_secrets" {
  source_file = "${path.module}/../secrets/infrastructure-secrets.yml.enc"
  input_type  = "yaml"
}

# Parse YAML and extract values with validation
locals {
  secrets = yamldecode(data.sops_file.infrastructure_secrets.raw)

  # Validate and extract hcloud_token
  hcloud_token = try(
    local.secrets["hcloud_token"],
    error("hcloud_token is required in infrastructure-secrets.yml.enc but was not found")
  )

  # Validate and extract ssh_keys (must be a list)
  ssh_keys_raw = try(
    local.secrets["ssh_keys"],
    error("ssh_keys is required in infrastructure-secrets.yml.enc but was not found")
  )

  # Ensure ssh_keys is a list and convert to list of strings
  ssh_keys_list = can(tolist(local.ssh_keys_raw)) ? tolist(local.ssh_keys_raw) : error("ssh_keys must be a list of Hetzner Cloud SSH key IDs")

  # Validate ssh_keys list is not empty
  ssh_keys_list_validated = length(local.ssh_keys_list) > 0 ? local.ssh_keys_list : error("ssh_keys list cannot be empty. At least one Hetzner Cloud SSH key ID is required")

  # Validate SSH key IDs are numeric (fail early if any are invalid)
  ssh_keys_invalid = [
    for key_id in local.ssh_keys_list_validated :
    key_id if !can(tonumber(key_id))
  ]
  ssh_keys = local.ssh_keys_list_validated

  # Validate and extract allowed_ssh_ips (must be a list)
  allowed_ssh_ips_raw = try(
    local.secrets["allowed_ssh_ips"],
    error("allowed_ssh_ips is required in infrastructure-secrets.yml.enc but was not found")
  )

  # Ensure allowed_ssh_ips is a list and convert to list of strings
  allowed_ssh_ips_list = can(tolist(local.allowed_ssh_ips_raw)) ? tolist(local.allowed_ssh_ips_raw) : error("allowed_ssh_ips must be a list of IP addresses or CIDR blocks")

  # Validate allowed_ssh_ips list is not empty
  allowed_ssh_ips_list_validated = length(local.allowed_ssh_ips_list) > 0 ? local.allowed_ssh_ips_list : error("allowed_ssh_ips list cannot be empty. At least one allowed IP address is required")

  # Validate IP addresses are valid CIDR format (fail early if any are invalid)
  # Accept both plain IPs (e.g., "1.2.3.4") and CIDR blocks (e.g., "1.2.3.4/32")
  ssh_ips_invalid = [
    for ip in local.allowed_ssh_ips_list_validated :
    ip if !can(cidrhost(length(regexall("/", ip)) > 0 ? ip : "${ip}/32", 0))
  ]
  allowed_ssh_ips = local.allowed_ssh_ips_list_validated
}

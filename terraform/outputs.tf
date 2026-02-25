output "server_ipv4" {
  description = "IPv4 address of the server - use this to SSH"
  value       = hcloud_server.platform.ipv4_address
}

output "server_ipv6" {
  description = "IPv6 address of the server"
  value       = hcloud_server.platform.ipv6_address
}

output "ssh_command" {
  description = "Command to SSH into the server (as ubuntu user for manual admin work)"
  value       = nonsensitive("ssh ubuntu@${local.environment}.${local.base_domain}")
}


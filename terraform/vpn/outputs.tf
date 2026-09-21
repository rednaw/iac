output "server_ipv4" {
  description = "IPv4 address of the VPN server — SSH target and share-link address"
  value       = hcloud_primary_ip.v4.ip_address
}

output "server_ipv6" {
  description = "IPv6 address of the VPN server (box is dual-stack; links stay IPv4)"
  value       = module.server.ipv6_address
}

output "primary_ipv4_id" {
  description = "Hetzner primary IPv4 resource ID (target for provision:renew-ip replace)"
  value       = hcloud_primary_ip.v4.id
}

output "ssh_command" {
  description = "Command to SSH into the server (after hostkeys:accept)"
  value       = "ssh -4 ubuntu@${hcloud_primary_ip.v4.ip_address}"
}

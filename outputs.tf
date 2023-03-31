output "keycloak_hostname" {
  description = "The hostname of the keycloak server"
  value       = var.hostname
}

output "keycloak_admin_username" {
  description = "Keycloak initial admin username"
  value       = local.keycloak_admin_username
  sensitive   = true
}

output "keycloak_admin_password" {
  description = "Keycloak initial admin password"
  value       = local.keycloak_admin_initial_password
  sensitive   = true
}

output "keycloak_public_lb_dns_name" {
  description = "The DNS name of the public load balancer"
  value       = module.public_alb.lb_dns_name
}

output "keycloak_private_lb_dns_name" {
  description = "The DNS name of the private load balancer"
  value       = var.enable_internal_load_balancer ? module.private_alb[0].lb_dns_name : null
}

output "service_discovery_dns_name" {
  description = "The DNS name of the service using AWS CloudMap"
  value       = "${local.service_discovery_service_name}.${local.service_discovery_namespace_name}"
}

output "service_discovery_dns_zone_id" {
  description = "The hosted zone ID of the service using AWS CloudMap"
  value       = aws_service_discovery_private_dns_namespace.this.hosted_zone
}

output "keycloak_security_group_id" {
  description = "The security group ID of the keycloak server"
  value       = module.keycloak_ingress.security_group_id
}

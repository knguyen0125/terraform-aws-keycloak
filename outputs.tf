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

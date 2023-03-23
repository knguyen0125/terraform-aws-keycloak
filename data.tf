data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  name = var.name

  keycloak_environment_variables = merge(var.is_optimized ? {} : var.keycloak_configuration_build_options, {
    KC_LOG_LEVEL          = var.keycloak_log_level
    KC_LOG_CONSOLE_COLOR  = "false"
    KC_LOG_CONSOLE_OUTPUT = "json"

    KC_PROXY        = "edge"
    KC_HOSTNAME     = var.hostname
    KC_HTTP_ENABLED = "true"
  })

  keycloak_secrets = {
    "KEYCLOAK_ADMIN"          = "${aws_secretsmanager_secret.initial_admin_password.arn}:username::"
    "KEYCLOAK_ADMIN_PASSWORD" = "${aws_secretsmanager_secret.initial_admin_password.arn}:password::"
    "KC_DB_URL_HOST"          = "${var.keycloak_database_configuration_secret_manager_arn}:host::"
    "KC_DB_URL_PORT"          = "${var.keycloak_database_configuration_secret_manager_arn}:port::"
    "KC_DB_URL_DATABASE"      = "${var.keycloak_database_configuration_secret_manager_arn}:dbname::"
    "KC_DB_URL_USERNAME"      = "${var.keycloak_database_configuration_secret_manager_arn}:username::"
    "KC_DB_URL_PASSWORD"      = "${var.keycloak_database_configuration_secret_manager_arn}:password::"
  }
}

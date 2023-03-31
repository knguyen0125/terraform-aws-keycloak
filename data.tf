data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_password" "keycloak_admin_initial_password" {
  count = var.keycloak_admin_initial_password == null ? 1 : 0

  length = 16
}

locals {
  name = "${var.name}-${random_string.suffix.result}"

  keycloak_admin_username         = var.keycloak_admin_username
  keycloak_admin_initial_password = var.keycloak_admin_initial_password == null ? random_password.keycloak_admin_initial_password[0].result : var.keycloak_admin_initial_password

  normalized_name                  = lower(replace(local.name, "/[^a-zA-Z0-9]/", "-"))
  service_discovery_namespace_name = var.service_discovery_namespace_name == null ? "${local.normalized_name}.local" : var.service_discovery_namespace_name
  service_discovery_service_name   = "instance"


  java_max_memory     = max(var.keycloak_container_limit_memory - var.keycloak_system_reserved_memory, var.keycloak_system_reserved_memory)
  java_initial_memory = max(floor(local.java_max_memory / 4), var.keycloak_system_reserved_memory)

  keycloak_environment_variables = merge(var.is_optimized ? {} : var.keycloak_configuration_build_options, {
    KC_LOG_LEVEL          = var.keycloak_log_level
    KC_LOG_CONSOLE_COLOR  = "false"
    KC_LOG_CONSOLE_OUTPUT = "json"

    KC_PROXY        = "edge"
    KC_HOSTNAME     = var.hostname
    KC_HTTP_ENABLED = "true"
    KC_HTTP_PORT    = "${var.keycloak_http_port}"
    KC_HTTPS_PORT   = "${var.keycloak_https_port}"


    JAVA_OPTS_APPEND = "-Djgroups.dns.query=${local.service_discovery_service_name}.${local.service_discovery_namespace_name} -Xmx${local.java_max_memory}m -Xms${local.java_initial_memory}m "
  }, var.keycloak_additional_environment_variables)

  keycloak_secrets = {
    "KEYCLOAK_ADMIN"          = "${aws_secretsmanager_secret.initial_admin_password.arn}:username::"
    "KEYCLOAK_ADMIN_PASSWORD" = "${aws_secretsmanager_secret.initial_admin_password.arn}:password::"

    "KC_DB_URL_HOST"     = "${var.keycloak_database_configuration_secret_manager_arn}:host::"
    "KC_DB_URL_PORT"     = "${var.keycloak_database_configuration_secret_manager_arn}:port::"
    "KC_DB_URL_DATABASE" = "${var.keycloak_database_configuration_secret_manager_arn}:dbname::"

    "KC_DB_USERNAME" = "${var.keycloak_database_configuration_secret_manager_arn}:username::"
    "KC_DB_PASSWORD" = "${var.keycloak_database_configuration_secret_manager_arn}:password::"
  }
}

data "aws_kms_key" "keycloak_admin_credentials_kms_key" {
  count = var.keycloak_admin_credentials_kms_key_id == null ? 0 : 1

  key_id = var.keycloak_admin_credentials_kms_key_id
}

data "aws_kms_key" "keycloak_database_configuration_kms_key" {
  count = var.keycloak_database_configuration_kms_key_id == null ? 0 : 1

  key_id = var.keycloak_database_configuration_kms_key_id
}


data "aws_iam_policy_document" "ecs_task_execution_policy" {
  statement {
    effect  = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      aws_secretsmanager_secret.initial_admin_password.arn, var.keycloak_database_configuration_secret_manager_arn
    ]
  }

  dynamic "statement" {
    for_each = var.keycloak_admin_credentials_kms_key_id == null ? [] : [1]

    content {
      effect  = "Allow"
      actions = [
        "kms:Decrypt",
      ]
      resources = [
        data.aws_kms_key.keycloak_admin_credentials_kms_key[0].arn
      ]
    }
  }

  dynamic "statement" {
    for_each = var.keycloak_database_configuration_kms_key_id == null ? [] : [1]

    content {
      effect  = "Allow"
      actions = [
        "kms:Decrypt",
      ]
      resources = [
        data.aws_kms_key.keycloak_database_configuration_kms_key[0].arn
      ]
    }
  }
}

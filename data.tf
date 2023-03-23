data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  name = var.name

  normalized_name = replace(local.name, "/[^a-zA-Z0-9]/", "-")
  service_discovery_namespace_name = "${local.normalized_name}.local"
  infinispan_service_discovery_service_name = "infinispan"

  keycloak_environment_variables = merge(var.is_optimized ? {} : var.keycloak_configuration_build_options, {
    KC_LOG_LEVEL          = var.keycloak_log_level
    KC_LOG_CONSOLE_COLOR  = "false"
    KC_LOG_CONSOLE_OUTPUT = "json"

    KC_PROXY        = "edge"
    KC_HOSTNAME     = var.hostname
    KC_HTTP_ENABLED = "true"

    JAVA_OPTS_APPEND = "-Djgroups.dns.query=${local.infinispan_service_discovery_service_name}.${local.service_discovery_namespace_name}"
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
    effect = "Allow"
    actions = [
      "secretmanager:GetSecretValue",
    ]
    resources = [
      aws_secretsmanager_secret.initial_admin_password.arn,
      var.keycloak_database_configuration_secret_manager_arn
    ]
  }

  dynamic "statement" {
    for_each = var.keycloak_admin_credentials_kms_key_id == null ? [] : [1]

    content {
      effect = "Allow"
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
      effect = "Allow"
      actions = [
        "kms:Decrypt",
      ]
      resources = [
        data.aws_kms_key.keycloak_database_configuration_kms_key[0].arn
      ]
    }
  }
}

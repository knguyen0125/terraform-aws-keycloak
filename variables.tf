variable "name" {
  type        = string
  description = "Name of the Keycloak cluster"
  default     = "keycloak"
}

variable "keycloak_image" {
  type        = string
  description = "Keycloak Image"
  default     = "quay.io/keycloak/keycloak:21.0.1"
}

variable "keycloak_container_limit_cpu" {
  type        = string
  description = "Keycloak container CPU limit"
  default     = "1024"
}

variable "keycloak_container_limit_memory" {
  type        = string
  description = "Keycloak container memory limit"
  default     = "2048"
}

variable "hostname" {
  type        = string
  description = "Keycloak Hostname"
}

variable "keycloak_admin_username" {
  type        = string
  description = "Keycloak Admin Username"
  default     = "admin"
}

variable "keycloak_admin_initial_password" {
  type        = string
  description = "Keycloak Admin Initial Password. If not provided, a random password will be generated"
  default     = null
}

variable "keycloak_admin_credentials_kms_key_id" {
  type        = string
  description = "KMS Key ID to encrypt the Keycloak Admin Password"
  default     = null
}

variable "keycloak_configuration_build_options" {
  type        = map(string)
  description = "Keycloak Configurations - Build Options. These options will be ignored by Keycloak if the provided image has already been configured"
  default = {
    KC_CACHE           = "ispn"
    KC_CACHE_STACK     = "kubernetes"
    KC_HEATH_ENABLED   = "true"
    KC_METRICS_ENABLED = "true"
    KC_DB              = "postgres"
  }
}

variable "keycloak_database_configuration_secret_manager_arn" {
  type        = string
  description = "Secret Manager ARN to retrieve the Keycloak Database Configuration. The database configuration must be in this format: `{\"dbname\":\"keycloak\",\"host\":\"keycloak-database.cluster-xxxxxx.us-east-1.rds.amazonaws.com\",\"port\":5432,\"username\":\"keycloak\",\"password\":\"xxxxxx\"}`"
}

variable "keycloak_database_configuration_kms_key_id" {
  type        = string
  description = "KMS Key ID to encrypt the Keycloak Database Configuration"
  default     = null
}

variable "tls_acm_certificate_arn" {
  type        = string
  description = "ACM Certificate ARN to use for the Keycloak Load Balancer"
}

variable "tls_ssl_policy" {
  type        = string
  description = "SSL Policy to use for the Keycloak Load Balancer"
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "keycloak_log_level" {
  type        = string
  description = "Keycloak Log Level"
  default     = "info"
}

variable "ecs_log_retention_in_days" {
  type        = number
  description = "Log retention in days for ECS logs"
  default     = 7
}

variable "keycloak_desired_count" {
  type        = number
  description = "Number of Keycloak instances to run"
  default     = 3
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to deploy the Keycloak cluster"
}

variable "keycloak_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs to deploy the Keycloak cluster"
}

variable "is_optimized" {
  type        = bool
  description = "Whether keycloak is optimized for production. If `true`, Keycloak will ignore build configurations and use the provide image. Defaults to `false` because we're using Keycloak official image"
  default     = false
}

variable "public_alb_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs to deploy the public ALB"
}

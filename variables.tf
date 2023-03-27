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
  type        = number
  description = "Keycloak container CPU limit. 1024 = 1 vCPU"
  default     = 1024
}

variable "keycloak_container_limit_memory" {
  type        = number
  description = "Keycloak container memory limit, in MiB"
  default     = 2048
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
  default     = {
    KC_CACHE           = "ispn"
    KC_CACHE_STACK     = "kubernetes"
    KC_HEALTH_ENABLED  = "true"
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
  description = "Whether keycloak is optimized for production. If `true`, Keycloak will ignore build configurations and assume that the provided image is already optimized. Defaults to `false` because we're using Keycloak official image"
  default     = false
}

variable "public_alb_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs to deploy the public ALB"
}

variable "keycloak_http_port" {
  type        = number
  description = "Keycloak HTTP Port"
  default     = 8080
}

variable "keycloak_https_port" {
  type        = number
  description = "Keycloak HTTPS Port"
  default     = 8443
}

variable "keycloak_jgroups_port" {
  type        = number
  description = "Keycloak JGroups Port"
  default     = 7800
}

variable "additional_security_groups" {
  type        = list(string)
  description = "Additional Security Groups to attach to the Keycloak cluster"
  default     = []
}

variable "keycloak_system_reserved_memory" {
  type        = number
  description = "Keycloak System Reserved Memory"
  default     = 256
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}

variable "keycloak_additional_environment_variables" {
  type        = map(string)
  description = "Additional environment variables to pass to the Keycloak container"
  default     = {}
}

variable "desired_capacity" {
  type        = number
  description = "Number of desired Keycloak instances to run. Only effective during the first deployment. After that, the autoscaling group will take care of the desired capacity"
  default     = 3
}

variable "autoscaling_enabled" {
  type        = bool
  description = "Whether to enable autoscaling"
  default     = true
}

variable "autoscaling_min_capacity" {
  type        = number
  description = "Minimum number of Keycloak instances to run"
  default     = 2
}

variable "autoscaling_max_capacity" {
  type        = number
  description = "Maximum number of Keycloak instances to run"
  default     = 3
}

variable "autoscaling_cpu_enabled" {
  type        = bool
  description = "Whether to enable autoscaling based on CPU utilization"
  default     = true
}

variable "autoscaling_cpu_target" {
  type        = number
  description = "Average CPU utilization to trigger autoscaling"
  default     = 50
}

variable "autoscaling_cpu_scale_in_cooldown" {
  type        = number
  description = "Cooldown period (in seconds) after a scale-in action has taken place"
  default     = 300
}

variable "autoscaling_cpu_scale_out_cooldown" {
  type        = number
  description = "Cooldown period (in seconds) after a scale-out action has taken place"
  default     = 300
}

variable "autoscaling_cpu_disable_scale_in" {
  type        = bool
  description = "Whether to disable scale-in actions"
  default     = false
}

variable "autoscaling_memory_enabled" {
  type        = bool
  description = "Whether to enable autoscaling based on Memory utilization"
  default     = true
}

variable "autoscaling_memory_target" {
  type        = number
  description = "Average Memory utilization to trigger autoscaling"
  default     = 50
}

variable "autoscaling_memory_scale_in_cooldown" {
  type        = number
  description = "Cooldown period (in seconds) after a scale-in action has taken place"
  default     = 300
}

variable "autoscaling_memory_scale_out_cooldown" {
  type        = number
  description = "Cooldown period (in seconds) after a scale-out action has taken place"
  default     = 300
}

variable "autoscaling_memory_disable_scale_in" {
  type        = bool
  description = "Whether to disable scale-in actions"
  default     = false
}


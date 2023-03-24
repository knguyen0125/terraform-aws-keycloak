# AWS Keycloak Terraform Module

This module deploys a production-ready Keycloak cluster to AWS.

## Health Checks

Starting Keycloak 21, the official Docker image no longer contain `curl`, which make it impossible to use
the `HEALTHCHECK` instruction for ECS.

Strictly speaking, we don't need a health check for Keycloak itself, as this module also provision a load balancer in
front of the cluster, which will perform health checks on the instances.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4.29 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.4 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.60.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.4.3 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ecs_task_execution_role"></a> [ecs\_task\_execution\_role](#module\_ecs\_task\_execution\_role) | terraform-aws-modules/iam/aws//modules/iam-assumable-role | 5.14.3 |
| <a name="module_keycloak_egress"></a> [keycloak\_egress](#module\_keycloak\_egress) | terraform-aws-modules/security-group/aws | 4.17.1 |
| <a name="module_keycloak_ingress"></a> [keycloak\_ingress](#module\_keycloak\_ingress) | terraform-aws-modules/security-group/aws | 4.17.1 |
| <a name="module_public_alb"></a> [public\_alb](#module\_public\_alb) | terraform-aws-modules/alb/aws | 8.5.0 |
| <a name="module_public_alb_security_group"></a> [public\_alb\_security\_group](#module\_public\_alb\_security\_group) | terraform-aws-modules/security-group/aws | 4.17.1 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.ecs_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_ecs_service.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_policy.ecs_task_execution_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_secretsmanager_secret.initial_admin_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.initial_admin_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_service_discovery_private_dns_namespace.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_private_dns_namespace) | resource |
| [aws_service_discovery_service.infinispan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service) | resource |
| [aws_wafv2_web_acl.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [random_password.keycloak_admin_initial_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.ecs_task_execution_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_kms_key.keycloak_admin_credentials_kms_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_key) | data source |
| [aws_kms_key.keycloak_database_configuration_kms_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_key) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_security_groups"></a> [additional\_security\_groups](#input\_additional\_security\_groups) | Additional Security Groups to attach to the Keycloak cluster | `list(string)` | `[]` | no |
| <a name="input_ecs_log_retention_in_days"></a> [ecs\_log\_retention\_in\_days](#input\_ecs\_log\_retention\_in\_days) | Log retention in days for ECS logs | `number` | `7` | no |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | Keycloak Hostname | `string` | n/a | yes |
| <a name="input_is_optimized"></a> [is\_optimized](#input\_is\_optimized) | Whether keycloak is optimized for production. If `true`, Keycloak will ignore build configurations and assume that the provided image is already optimized. Defaults to `false` because we're using Keycloak official image | `bool` | `false` | no |
| <a name="input_keycloak_additional_environment_variables"></a> [keycloak\_additional\_environment\_variables](#input\_keycloak\_additional\_environment\_variables) | Additional environment variables to pass to the Keycloak container | `map(string)` | `{}` | no |
| <a name="input_keycloak_admin_credentials_kms_key_id"></a> [keycloak\_admin\_credentials\_kms\_key\_id](#input\_keycloak\_admin\_credentials\_kms\_key\_id) | KMS Key ID to encrypt the Keycloak Admin Password | `string` | `null` | no |
| <a name="input_keycloak_admin_initial_password"></a> [keycloak\_admin\_initial\_password](#input\_keycloak\_admin\_initial\_password) | Keycloak Admin Initial Password. If not provided, a random password will be generated | `string` | `null` | no |
| <a name="input_keycloak_admin_username"></a> [keycloak\_admin\_username](#input\_keycloak\_admin\_username) | Keycloak Admin Username | `string` | `"admin"` | no |
| <a name="input_keycloak_configuration_build_options"></a> [keycloak\_configuration\_build\_options](#input\_keycloak\_configuration\_build\_options) | Keycloak Configurations - Build Options. These options will be ignored by Keycloak if the provided image has already been configured | `map(string)` | <pre>{<br>  "KC_CACHE": "ispn",<br>  "KC_CACHE_STACK": "kubernetes",<br>  "KC_DB": "postgres",<br>  "KC_HEALTH_ENABLED": "true",<br>  "KC_METRICS_ENABLED": "true"<br>}</pre> | no |
| <a name="input_keycloak_container_limit_cpu"></a> [keycloak\_container\_limit\_cpu](#input\_keycloak\_container\_limit\_cpu) | Keycloak container CPU limit | `number` | `1024` | no |
| <a name="input_keycloak_container_limit_memory"></a> [keycloak\_container\_limit\_memory](#input\_keycloak\_container\_limit\_memory) | Keycloak container memory limit | `number` | `2048` | no |
| <a name="input_keycloak_database_configuration_kms_key_id"></a> [keycloak\_database\_configuration\_kms\_key\_id](#input\_keycloak\_database\_configuration\_kms\_key\_id) | KMS Key ID to encrypt the Keycloak Database Configuration | `string` | `null` | no |
| <a name="input_keycloak_database_configuration_secret_manager_arn"></a> [keycloak\_database\_configuration\_secret\_manager\_arn](#input\_keycloak\_database\_configuration\_secret\_manager\_arn) | Secret Manager ARN to retrieve the Keycloak Database Configuration. The database configuration must be in this format: `{"dbname":"keycloak","host":"keycloak-database.cluster-xxxxxx.us-east-1.rds.amazonaws.com","port":5432,"username":"keycloak","password":"xxxxxx"}` | `string` | n/a | yes |
| <a name="input_keycloak_desired_count"></a> [keycloak\_desired\_count](#input\_keycloak\_desired\_count) | Number of Keycloak instances to run | `number` | `3` | no |
| <a name="input_keycloak_http_port"></a> [keycloak\_http\_port](#input\_keycloak\_http\_port) | Keycloak HTTP Port | `number` | `8080` | no |
| <a name="input_keycloak_https_port"></a> [keycloak\_https\_port](#input\_keycloak\_https\_port) | Keycloak HTTPS Port | `number` | `8443` | no |
| <a name="input_keycloak_image"></a> [keycloak\_image](#input\_keycloak\_image) | Keycloak Image | `string` | `"quay.io/keycloak/keycloak:21.0.1"` | no |
| <a name="input_keycloak_jgroups_port"></a> [keycloak\_jgroups\_port](#input\_keycloak\_jgroups\_port) | Keycloak JGroups Port | `number` | `7800` | no |
| <a name="input_keycloak_log_level"></a> [keycloak\_log\_level](#input\_keycloak\_log\_level) | Keycloak Log Level | `string` | `"info"` | no |
| <a name="input_keycloak_subnet_ids"></a> [keycloak\_subnet\_ids](#input\_keycloak\_subnet\_ids) | Subnet IDs to deploy the Keycloak cluster | `list(string)` | n/a | yes |
| <a name="input_keycloak_system_reserved_memory"></a> [keycloak\_system\_reserved\_memory](#input\_keycloak\_system\_reserved\_memory) | Keycloak System Reserved Memory | `number` | `256` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the Keycloak cluster | `string` | `"keycloak"` | no |
| <a name="input_public_alb_subnet_ids"></a> [public\_alb\_subnet\_ids](#input\_public\_alb\_subnet\_ids) | Subnet IDs to deploy the public ALB | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_tls_acm_certificate_arn"></a> [tls\_acm\_certificate\_arn](#input\_tls\_acm\_certificate\_arn) | ACM Certificate ARN to use for the Keycloak Load Balancer | `string` | n/a | yes |
| <a name="input_tls_ssl_policy"></a> [tls\_ssl\_policy](#input\_tls\_ssl\_policy) | SSL Policy to use for the Keycloak Load Balancer | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID to deploy the Keycloak cluster | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_keycloak_admin_password"></a> [keycloak\_admin\_password](#output\_keycloak\_admin\_password) | Keycloak initial admin password |
| <a name="output_keycloak_admin_username"></a> [keycloak\_admin\_username](#output\_keycloak\_admin\_username) | Keycloak initial admin username |
| <a name="output_keycloak_hostname"></a> [keycloak\_hostname](#output\_keycloak\_hostname) | The hostname of the keycloak server |
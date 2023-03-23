# IAM
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
      "secretmanager:GetSecretValue",
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

resource "aws_iam_policy" "ecs_task_execution_policy" {
  name   = "${local.name}-ecs-task-execution-policy"
  policy = data.aws_iam_policy_document.ecs_task_execution_policy.json
}

module "ecs_task_execution_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.14.3"

  role_name = "${local.name}-ecs-task-execution-role"

  role_requires_mfa = false

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  number_of_custom_role_policy_arns = 2
  custom_role_policy_arns           = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    aws_iam_policy.ecs_task_execution_policy.arn
  ]
}

# ECS
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name = "/ecs/${local.name}"

  retention_in_days = var.ecs_log_retention_in_days
}

resource "aws_ecs_task_definition" "keycloak" {
  family = "${local.name}-task-definition"

  container_definitions = jsonencode([
    {
      name         = "keycloak"
      image        = var.keycloak_image
      command      = var.is_optimized ? ["start", "--optimized"] : ["start"]
      essential    = true
      portMappings = [
        {
          name          = "keycloak-http"
          containerPort = 8080
          protocol      = "tcp"
        }, {
          name          = "keycloak-https"
          containerPort = 8443
          protocol      = "tcp"
        }, {
          name          = "keycloak-jgroups"
          containerPort = 7600
          protocol      = "tcp"
        }
      ]
      environment = [
        for k, v in local.keycloak_environment_variables : {
          name  = k
          value = v
        }
      ]
      secrets = [
        for k, v in local.keycloak_secrets : {
          name      = k
          valueFrom = v
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = data.aws_region.current
          "awslogs-stream-prefix" = "keycloak"
        }
      }
    }
  ]

  )

  cpu    = var.keycloak_container_limit_cpu
  memory = var.keycloak_container_limit_memory

  execution_role_arn = module.ecs_task_execution_role.iam_role_arn

  network_mode             = "awsvpc"
  requires_compatibilities = [
    "FARGATE"
  ]
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
}

resource "aws_ecs_cluster" "keycloak" {
  name = "${local.name}-cluster"
}

resource "aws_ecs_cluster_capacity_providers" "keycloak" {
  cluster_name       = aws_ecs_cluster.keycloak.name
  capacity_providers = [
    "FARGATE"
  ]
}

# Keycloak Security Group - Unrestricted Access to Keycloak from self
module "keycloak_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.17.1"

  name        = "${local.name}-self-sg"
  description = "Keycloak Security Group - Unrestricted Access to Keycloak from self"
  vpc_id      = var.vpc_id

  ingress_with_self = [
    {
      rule = "all-all"
    }
  ]

  egress_rules = ["all-all"]
}

resource "aws_ecs_service" "keycloak" {
  name = "${local.name}-service"

  task_definition = aws_ecs_task_definition.keycloak.family

  desired_count = var.keycloak_desired_count

  network_configuration {
    subnets         = var.keycloak_subnet_ids
    security_groups = [
      module.keycloak_security_group.security_group_id
    ]
  }

  cluster = aws_ecs_cluster.keycloak.name

  enable_ecs_managed_tags = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE"

    base   = 1
    weight = 100
  }

  load_balancer {
    elb_name         = module.public_alb.lb_id
    target_group_arn = module.public_alb.target_group_arns[0]
    container_name   = "keycloak"
    container_port   = 8080
  }

  health_check_grace_period_seconds = 300

  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }
}

# ALB
module "public_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "8.5.0"

  name               = "${var.name}-public"
  load_balancer_type = "application"

  vpc_id          = var.vpc_id
  subnets         = var.public_alb_subnet_ids
  security_groups = [
    module.keycloak_security_group.security_group_id
  ]

  preserve_host_header = true

  target_groups = [
    {
      name_prefix      = "${local.name}-https"
      backend_protocol = "HTTP"
      backend_port     = 8080
      target_type      = "ip"
      health_check     = {
        enabled             = true
        path                = "/health/ready"
        port                = "traffic-port"
        interval            = 30
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-299"
      }
      # Improve performance by enabling stickiness
      stickiness = {
        enabled     = true
        type        = "app_cookie"
        cookie_name = "AUTH_SESSION_ID"
      }
    }
  ]

  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = var.tls_acm_certificate_arn
      target_group_index = 0
      ssl_policy         = var.tls_ssl_policy
      action_type        = "fixed-response"
      fixed_response     = {
        content_type = "application/json"
        message_body = jsonencode({
          message = "Not Found"
        })
        status_code = "404"
      }
    }
  ]

  # Setup Redirection from HTTP to HTTPS
  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect    = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]

  https_listener_rules = [
    {
      https_listener_index = 0

      actions = [
        {
          type               = "forward"
          target_group_index = 0
        }
      ]

      conditions = [
        {
          host_headers = [var.hostname]
        }, {
          # The following paths are recommended for Keycloak. See https://www.keycloak.org/server/reverseproxy#_exposed_path_recommendations
          path_patterns = ["/js/*", "/realms/*", "/resources/*", "/robots.txt"]
        }
      ]
    }
  ]


}

# Keycloak Initial Admin
resource "random_password" "keycloak_admin_initial_password" {
  count = var.keycloak_admin_initial_password == null ? 1 : 0

  length = 16
}

locals {
  keycloak_admin_username         = var.keycloak_admin_username
  keycloak_admin_initial_password = var.keycloak_admin_initial_password == null ? random_password.keycloak_admin_initial_password[0].result : var.keycloak_admin_initial_password
}

resource "aws_secretsmanager_secret" "initial_admin_password" {
  name = "${var.name}-initial-admin-password"

  kms_key_id = var.keycloak_admin_credentials_kms_key_id
}

resource "aws_secretsmanager_secret_version" "initial_admin_password" {
  secret_id = aws_secretsmanager_secret.initial_admin_password.id

  secret_string = jsonencode({
    username = local.keycloak_admin_username
    password = local.keycloak_admin_initial_password
  })
}

resource "aws_wafv2_regex_pattern_set" "common" {
  name  = "Common"
  scope = "REGIONAL"

  regular_expression {
    regex_string = "^"
  }
}

# WAF
resource "aws_wafv2_web_acl" "acl" {
  name  = "${var.name}-acl"
  scope = "REGIONAL"

  default_action {
    block {}
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      count {

      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ExternalACL"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "this" {
  web_acl_arn  = aws_wafv2_web_acl.acl.arn
  resource_arn = module.public_alb.lb_arn
}

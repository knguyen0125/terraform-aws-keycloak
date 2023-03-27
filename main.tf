# IAM
resource "aws_iam_policy" "ecs_task_execution_policy" {
  name   = "${local.name}-ecs-task-execution-policy"
  policy = data.aws_iam_policy_document.ecs_task_execution_policy.json

  tags = var.tags
}

module "ecs_task_execution_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.14.3"

  create_role = true
  role_name   = "${local.name}-ecs-task-execution-role"

  role_requires_mfa = false

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  number_of_custom_role_policy_arns = 2
  custom_role_policy_arns           = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    aws_iam_policy.ecs_task_execution_policy.arn
  ]

  tags = var.tags
}

# ECS
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name = "/ecs/${local.name}"

  retention_in_days = var.ecs_log_retention_in_days

  tags = var.tags
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
          containerPort = var.keycloak_http_port
          protocol      = "tcp"
        }, {
          name          = "keycloak-https"
          containerPort = var.keycloak_https_port
          protocol      = "tcp"
        }, {
          name          = "keycloak-jgroups"
          containerPort = var.keycloak_jgroups_port
          protocol      = "tcp"
        }
      ]
      environment = [
        for k, v in local.keycloak_environment_variables : {
          name  = tostring(k)
          value = tostring(v)
        }
      ]
      secrets = [
        for k, v in local.keycloak_secrets : {
          name      = tostring(k)
          valueFrom = tostring(v)
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = "keycloak"
        }
      }
    }
  ])

  cpu    = tostring(var.keycloak_container_limit_cpu)
  memory = tostring(var.keycloak_container_limit_memory)

  execution_role_arn = module.ecs_task_execution_role.iam_role_arn

  network_mode             = "awsvpc"
  requires_compatibilities = [
    "FARGATE"
  ]
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = var.tags
}

resource "aws_ecs_cluster" "keycloak" {
  name = "${local.name}-cluster"

  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "keycloak" {
  cluster_name       = aws_ecs_cluster.keycloak.name
  capacity_providers = [
    "FARGATE"
  ]
}

# Keycloak Security Group - Unrestricted Access to Keycloak from self
module "keycloak_ingress" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.17.1"

  name        = "${local.name}-self-sg"
  description = "Keycloak Security Group - Unrestricted Access to Keycloak from self"
  vpc_id      = var.vpc_id

  # Allow ingress to self. This Security group is also attached to the public load balancer
  # To allow access to Keycloak
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_with_self   = [
    {
      rule = "all-all"
    }
  ]

  tags = var.tags
}

module "keycloak_egress" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.17.1"

  name        = "${local.name}-egress-sg"
  description = "Keycloak Security Group - Egress from Keycloak"
  vpc_id      = var.vpc_id

  # Keycloak needs to be able to call other services in the cluster
  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["all-all"]

  tags = var.tags
}

resource "aws_ecs_service" "keycloak" {
  name = "${local.name}-service"

  task_definition = aws_ecs_task_definition.keycloak.family

  desired_count = var.desired_capacity

  network_configuration {
    assign_public_ip = true
    subnets          = var.keycloak_subnet_ids
    security_groups  = concat([
      module.keycloak_ingress.security_group_id, module.keycloak_egress.security_group_id
    ], var.additional_security_groups)
  }

  cluster = aws_ecs_cluster.keycloak.name

  enable_ecs_managed_tags = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE"

    base   = 1
    weight = 100
  }

  load_balancer {
    target_group_arn = module.public_alb.target_group_arns[0]
    container_name   = "keycloak"
    container_port   = var.keycloak_http_port
  }

  health_check_grace_period_seconds = 300

  service_registries {
    registry_arn   = aws_service_discovery_service.infinispan.arn
    container_name = "keycloak"
  }

  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }

  tags = var.tags
}


# Keycloak Initial Admin
resource "aws_secretsmanager_secret" "initial_admin_password" {
  name = "${local.name}-initial-admin-password"

  kms_key_id = var.keycloak_admin_credentials_kms_key_id

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "initial_admin_password" {
  secret_id = aws_secretsmanager_secret.initial_admin_password.id

  secret_string = jsonencode({
    username = local.keycloak_admin_username
    password = local.keycloak_admin_initial_password
  })
}

resource "aws_service_discovery_private_dns_namespace" "keycloak" {
  name        = local.service_discovery_namespace_name
  description = "Service Discovery Namespace for Keycloak"
  vpc         = var.vpc_id

  tags = var.tags
}

resource "aws_service_discovery_service" "infinispan" {
  name = local.infinispan_service_discovery_service_name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.keycloak.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = var.tags
}

resource "aws_appautoscaling_target" "this" {
  count              = var.autoscaling_enabled ? 1 : 0
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.keycloak.name}/${aws_ecs_service.keycloak.name}"
  scalable_dimension = "ecs:service:DesiredCount"

  max_capacity = var.autoscaling_max_capacity
  min_capacity = var.autoscaling_min_capacity
}

resource "aws_appautoscaling_policy" "cpu" {
  count              = var.autoscaling_enabled && var.autoscaling_cpu_enabled ? 1 : 0
  name               = "${local.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.autoscaling_cpu_target
    scale_in_cooldown  = var.autoscaling_cpu_scale_in_cooldown
    scale_out_cooldown = var.autoscaling_cpu_scale_out_cooldown
    disable_scale_in   = var.autoscaling_cpu_disable_scale_in
  }
}

resource "aws_appautoscaling_policy" "memory" {
  count              = var.autoscaling_enabled && var.autoscaling_memory_enabled ? 1 : 0
  name               = "${local.name}-memory"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = var.autoscaling_memory_target
    scale_in_cooldown  = var.autoscaling_memory_scale_in_cooldown
    scale_out_cooldown = var.autoscaling_memory_scale_out_cooldown
    disable_scale_in   = var.autoscaling_memory_disable_scale_in
  }
}

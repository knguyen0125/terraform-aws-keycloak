module "public_alb_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.17.1"

  name        = "${local.name}-alb-sg"
  description = "Keycloak Security Group - ALB"
  vpc_id      = var.vpc_id


  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp", "http-80-tcp"]


  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["all-all"]

  tags = var.tags
}

# ALB
module "public_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "8.5.0"

  name               = "${var.name}-public"
  load_balancer_type = "application"

  vpc_id = var.vpc_id

  subnets = var.public_alb_subnet_ids

  security_groups = [
    module.keycloak_egress.security_group_id, module.public_alb_security_group.security_group_id
  ]

  preserve_host_header = true

  target_groups = [
    {
      name                 = "${local.name}-https"
      backend_protocol     = "HTTP"
      backend_port         = var.keycloak_http_port
      target_type          = "ip"
      deregistration_delay = 60
      health_check = {
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

      # By default, the ALB will return a 404 for any requests that don't match a rule.
      action_type = "fixed-response"
      fixed_response = {
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
      redirect = {
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
        },
        {
          # The following paths are recommended for Keycloak. See https://www.keycloak.org/server/reverseproxy#_exposed_path_recommendations
          path_patterns = ["/js/*", "/realms/*", "/resources/*", "/robots.txt"]
        }
      ]
    }
  ]

  tags = var.tags
}

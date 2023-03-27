provider "aws" {}
provider "random" {}

variable "hostname" {
  type = string
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.17.1"

  name            = "rds-sg"
  use_name_prefix = true
  description     = "RDS SG"
  vpc_id          = data.aws_vpc.default.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["all-all"]
  # Keycloak needs to be able to call other services in the cluster
  egress_cidr_blocks  = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "5.6.0"

  identifier = "keycloak"

  publicly_accessible = true

  engine         = "postgres"
  engine_version = "15.2"
  family         = "postgres15"

  instance_class    = "db.t3.micro"
  allocated_storage = "5"

  db_name  = "keycloak"
  username = "keycloak"

  create_random_password = false
  password               = "keycloak"

  vpc_security_group_ids = [module.security_group.security_group_id]


  create_db_subnet_group = true
  subnet_ids             = [data.aws_subnets.subnets.ids[0], data.aws_subnets.subnets.ids[1]]
}

resource "aws_secretsmanager_secret" "database" {
  name = "keycloak-database"
}

resource "aws_secretsmanager_secret_version" "databaes" {
  secret_id     = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    dbname   = "keycloak"
    username = module.rds.db_instance_username
    password = module.rds.db_instance_password
    host     = module.rds.db_instance_address
    port     = module.rds.db_instance_port
  })
}

resource "aws_acm_certificate" "this" {
  domain_name       = var.hostname
  validation_method = "DNS"
}

module "keycloak" {
  source = "../.."

  desired_capacity = 1

  hostname = var.hostname

  keycloak_database_configuration_secret_manager_arn = aws_secretsmanager_secret.database.arn

  keycloak_subnet_ids   = [data.aws_subnets.subnets.ids[0], data.aws_subnets.subnets.ids[1]]
  public_alb_subnet_ids = [data.aws_subnets.subnets.ids[0], data.aws_subnets.subnets.ids[1]]

  tls_acm_certificate_arn = aws_acm_certificate.this.arn

  vpc_id = data.aws_vpc.default.id

  additional_security_groups = [module.security_group.security_group_id]
}

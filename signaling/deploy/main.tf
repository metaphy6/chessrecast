terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    # Override with -backend-config in CI.
    bucket = "chessrecast-tfstate"
    key    = "signaling/terraform.tfstate"
    region = "us-east-1"
  }
}

# ── Variables ──────────────────────────────────────────────────────────────────
variable "regions" {
  type        = list(string)
  description = "Active-active regions. At least 2 required."
  default     = ["us-east-1", "eu-west-1"]
}

variable "image_tag" {
  type        = string
  description = "Container image tag for the signaling server."
  default     = "latest"
}

variable "ecr_repository" {
  type        = string
  description = "ECR repository URI (without tag)."
}

variable "task_cpu" {
  type    = number
  default = 256 # 0.25 vCPU
}

variable "task_memory" {
  type    = number
  default = 512 # MB
}

# ── Multi-region ECS Fargate (active-active) ───────────────────────────────────
locals {
  image = "${var.ecr_repository}:${var.image_tag}"
}

provider "aws" {
  alias  = "primary"
  region = var.regions[0]
}

provider "aws" {
  alias  = "secondary"
  region = var.regions[1]
}

module "signaling_primary" {
  source = "./modules/signaling_region"
  providers = {
    aws = aws.primary
  }
  region         = var.regions[0]
  image          = local.image
  task_cpu       = var.task_cpu
  task_memory    = var.task_memory
}

module "signaling_secondary" {
  source = "./modules/signaling_region"
  providers = {
    aws = aws.secondary
  }
  region         = var.regions[1]
  image          = local.image
  task_cpu       = var.task_cpu
  task_memory    = var.task_memory
}

# ── Latency-based DNS (Route53) ───────────────────────────────────────────────
# Each region module outputs its ALB DNS name; Route53 latency routing
# sends clients to the nearest region.
resource "aws_route53_record" "signaling_primary" {
  provider = aws.primary
  zone_id  = data.aws_route53_zone.main.zone_id
  name     = "signaling.chessrecast.com"
  type     = "A"
  latency_routing_policy {
    region = var.regions[0]
  }
  set_identifier = "primary"
  alias {
    name                   = module.signaling_primary.alb_dns_name
    zone_id                = module.signaling_primary.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "signaling_secondary" {
  provider = aws.secondary
  zone_id  = data.aws_route53_zone.main.zone_id
  name     = "signaling.chessrecast.com"
  type     = "A"
  latency_routing_policy {
    region = var.regions[1]
  }
  set_identifier = "secondary"
  alias {
    name                   = module.signaling_secondary.alb_dns_name
    zone_id                = module.signaling_secondary.alb_zone_id
    evaluate_target_health = true
  }
}

data "aws_route53_zone" "main" {
  provider = aws.primary
  name     = "chessrecast.com."
}

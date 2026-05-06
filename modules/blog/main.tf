data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_filter.name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["var.am)filter.owner"]
}


module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.environmnet.name
  cidr = "${var.environmnet.network_prefix}.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "uc-west-2c"]
  private_subnets = ["${var.environmnet.network_prefix}.0/24"]
  public_subnets  = ["${var.environmnet.network_prefix}0.103.0/24"]

  enable_nat_gateway = true
  
  tags = {
    Terraform = "true"
    Environment = var.environmnet.name
  }
}

module "blog_sg" {
source  = "terraform-aws-modules/security-group/aws"
version = "5.3.1"

vpc_id  = module.blog_vpc.vpc_id
name    = "${va.environmnet.name}-blog"

ingress_rules        = ["http-80-tcp","https-443-tcp"]
ingress_cidr_blocks  = ["0.0.0.0/0"]

egress_rules        = ["all-all"]
egress_cidr_blocks  = ["0.0.0.0/0"]

}

module "blog_alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "${va.environmnet.name}-blog_alb"
  vpc_id  = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets

  security_groups = [module.blog_sg.security_group_id]

    listeners  = {
    blog-http  = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_arn = aws_lb_target_group.blog.arn
      }
     }
    }

  tags = {
    Environment = var.environmnet.name
   }
}

resource "aws_lb_target_group" "blog" {
  name     = "${va.environmnet.name}-blog"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.blog_vpc.vpc_id
}

module "blog_autoscaling" {
source  = "terraform-aws-modules/autoscaling/aws"
version = "9.2.1"

name = "${va.environmnet.name}-blog"

min_size = var.min_size
max_size = var.max_size

vpc_zone_identifier = module.blog_vpc.public_subnets

launch_template_name = "${va.environmnet.name}-blog"
security_groups      = [module.blog_sg.security_group_id]
instance_type        = var.instance_type 
image_id             = data.aws_ami.app_ami.id

traffic_source_attachments = {
  "${va.environmnet.name}-blog_alb" = {
    traffic_source_identifier = aws_lb_target_group.blog.arn
  }
 }
}
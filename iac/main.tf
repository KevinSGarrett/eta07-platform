
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Random suffix for unique bucket names
resource "random_id" "suffix" {
  byte_length = 2
}

# S3 buckets
resource "aws_s3_bucket" "assets" {
  bucket = "eta07-assets-${var.env}-${random_id.suffix.hex}"
}
resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" } }
}

resource "aws_s3_bucket" "backups" {
  bucket = "eta07-backups-${var.env}-${random_id.suffix.hex}"
}
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    id = "retention-365"
    status = "Enabled"
    expiration { days = 365 }
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" } }
}

# EC2 security group: allow http/https
resource "aws_security_group" "web" {
  name        = "eta07-web-${var.env}"
  description = "Allow HTTP/HTTPS"
  vpc_id      = var.vpc_id
  ingress { from_port = 80  to_port = 80  protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 443 to_port = 443 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0   to_port = 0   protocol = "-1"  cidr_blocks = ["0.0.0.0/0"] }
  tags = { Project = "ETA07", Env = var.env }
}

# EC2 instance (simplified; use your existing VPC/subnet)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter { name = "name" values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"] }
}
resource "aws_instance" "directus" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [aws_security_group.web.id]
  associate_public_ip_address = true

  tags = {
    Name    = "eta07-directus-${var.env}"
    Project = "ETA07"
    Env     = var.env
  }
}

# Route53 A record for subdomain
resource "aws_route53_record" "app" {
  zone_id = var.route53_zone_id
  name    = "data.${var.domain}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.directus.public_ip]
}

output "assets_bucket"  { value = aws_s3_bucket.assets.bucket }
output "backups_bucket" { value = aws_s3_bucket.backups.bucket }
output "instance_ip"    { value = aws_instance.directus.public_ip }
output "subdomain"      { value = "data.${var.domain}" }

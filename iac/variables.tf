
variable "region"         { type = string  default = "us-east-1" }
variable "env"            { type = string  default = "prod" }
variable "domain"         { type = string  default = "eta07data.com" }
variable "route53_zone_id"{ type = string }
variable "vpc_id"         { type = string }
variable "subnet_id"      { type = string }
variable "instance_type"  { type = string  default = "t3.medium" }

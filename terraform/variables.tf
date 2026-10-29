variable "student_name" {
  description = "Your name (used for the Student tag)."
  type        = string
}

variable "bastion_allowed_cidr" {
  description = "Your current public IPv4 as a /32, e.g. 203.0.113.25/32. Required."
  type        = string
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/32$", var.bastion_allowed_cidr)) && var.bastion_allowed_cidr != "0.0.0.0/32"
    error_message = "Must be a single public IPv4 address in /32 form (never 0.0.0.0/0)."
  }
}

variable "aws_region" {
  description = "AWS Region. The verified final deployment uses us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile. Null = default credential chain."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "Instructor-approved small x86 type. Check pricing/availability."
  type        = string
  default     = "t3.micro"
}

variable "availability_zone" {
  description = "Same AZ for all subnets. Null = first available AZ in the Region."
  type        = string
  default     = null
}

variable "public_key_path" {
  description = "Path to the PUBLIC key (.pub). The private key never enters Terraform."
  type        = string
  default     = "~/.ssh/ewb-lab.pub"
}

variable "enable_peering" {
  description = "false = build everything except peering and peer routes (for the baseline test). true = full lab."
  type        = bool
  default     = true
}

variable "vpc_a_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "vpc_b_cidr" {
  type    = string
  default = "10.20.0.0/16"
  validation {
    condition = (
      try(cidrhost(var.vpc_a_cidr, 0) != cidrhost(var.vpc_b_cidr, 0), false) &&
      endswith(var.vpc_a_cidr, "/16") && endswith(var.vpc_b_cidr, "/16")
    )
    error_message = "Both VPC CIDRs must be /16 and must not overlap."
  }
}

variable "a_public_cidr" {
  type    = string
  default = "10.10.1.0/24"
}

variable "a_private_cidr" {
  type    = string
  default = "10.10.2.0/24"
}

variable "b_private_cidr" {
  type    = string
  default = "10.20.1.0/24"
}

variable "enable_app_b_ssh_from_app_a_test" {
  description = <<-EOT
    TEST-ONLY, default false. Adds TCP/22 ingress on ewb-sg-app-b from App-A (10.10.2.10/32)
    to test port reachability. It widens SSH beyond the bastion-only design, so enable it
    briefly and remove it afterwards. Do NOT enable it against the existing deployment, where
    an equivalent rule was added manually: Terraform would try to create a duplicate rule.
  EOT
  type        = bool
  default     = false
}

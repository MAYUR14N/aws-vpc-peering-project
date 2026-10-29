locals {
  az   = coalesce(var.availability_zone, data.aws_availability_zones.available.names[0])
  tags = { Project = "EWB-VPC-Peering", Student = var.student_name }

  bastion_ip = cidrhost(var.a_public_cidr, 10)  # 10.10.1.10
  app_a_ip   = cidrhost(var.a_private_cidr, 10) # 10.10.2.10
  app_b_ip   = cidrhost(var.b_private_cidr, 10) # 10.20.1.10
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------- VPC A ----------------
resource "aws_vpc" "a" {
  cidr_block           = var.vpc_a_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "ewb-vpc-a" }
}

resource "aws_subnet" "a_public" {
  vpc_id                  = aws_vpc.a.id
  cidr_block              = var.a_public_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false
  tags                    = { Name = "ewb-a-public" }
}

resource "aws_subnet" "a_private" {
  vpc_id                  = aws_vpc.a.id
  cidr_block              = var.a_private_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false
  tags                    = { Name = "ewb-a-private" }
}

resource "aws_internet_gateway" "a" {
  vpc_id = aws_vpc.a.id
  tags   = { Name = "ewb-igw-a" }
}

resource "aws_route_table" "a_public" {
  vpc_id = aws_vpc.a.id
  tags   = { Name = "ewb-rt-a-public" }
}

resource "aws_route_table" "a_private" {
  vpc_id = aws_vpc.a.id
  tags   = { Name = "ewb-rt-a-private" }
}

resource "aws_route_table_association" "a_public" {
  subnet_id      = aws_subnet.a_public.id
  route_table_id = aws_route_table.a_public.id
}

resource "aws_route_table_association" "a_private" {
  subnet_id      = aws_subnet.a_private.id
  route_table_id = aws_route_table.a_private.id
}

resource "aws_route" "a_public_default" {
  route_table_id         = aws_route_table.a_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.a.id
}

# ---------------- VPC B (no IGW) ----------------
resource "aws_vpc" "b" {
  cidr_block           = var.vpc_b_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "ewb-vpc-b" }
}

resource "aws_subnet" "b_private" {
  vpc_id                  = aws_vpc.b.id
  cidr_block              = var.b_private_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false
  tags                    = { Name = "ewb-b-private" }
}

resource "aws_route_table" "b_private" {
  vpc_id = aws_vpc.b.id
  tags   = { Name = "ewb-rt-b-private" }
}

resource "aws_route_table_association" "b_private" {
  subnet_id      = aws_subnet.b_private.id
  route_table_id = aws_route_table.b_private.id
}

# ---------------- Peering + routes (both directions) ----------------
resource "aws_vpc_peering_connection" "a_b" {
  count       = var.enable_peering ? 1 : 0
  vpc_id      = aws_vpc.a.id # requester
  peer_vpc_id = aws_vpc.b.id # accepter
  auto_accept = true         # same account + Region: Terraform accepts the request
  tags        = { Name = "ewb-a-b-peer" }
}

resource "aws_route" "a_public_to_b" {
  count                     = var.enable_peering ? 1 : 0
  route_table_id            = aws_route_table.a_public.id
  destination_cidr_block    = var.vpc_b_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}

resource "aws_route" "a_private_to_b" {
  count                     = var.enable_peering ? 1 : 0
  route_table_id            = aws_route_table.a_private.id
  destination_cidr_block    = var.vpc_b_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}

resource "aws_route" "b_private_to_a" {
  count                     = var.enable_peering ? 1 : 0
  route_table_id            = aws_route_table.b_private.id
  destination_cidr_block    = var.vpc_a_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}

# ---------------- Security groups ----------------
resource "aws_security_group" "bastion" {
  name        = "ewb-sg-bastion"
  description = "EWB bastion: SSH from student IP only"
  vpc_id      = aws_vpc.a.id
  tags        = { Name = "ewb-sg-bastion" }
}

resource "aws_security_group" "app_a" {
  name        = "ewb-sg-app-a"
  description = "EWB App-A: SSH from bastion, ping from App-B"
  vpc_id      = aws_vpc.a.id
  tags        = { Name = "ewb-sg-app-a" }
}

resource "aws_security_group" "app_b" {
  name        = "ewb-sg-app-b"
  description = "EWB App-B: SSH from bastion, ping from App-A"
  vpc_id      = aws_vpc.b.id
  tags        = { Name = "ewb-sg-app-b" }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH from student public IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.bastion_allowed_cidr
}

resource "aws_vpc_security_group_ingress_rule" "app_a_ssh" {
  security_group_id = aws_security_group.app_a.id
  description       = "SSH from bastion private IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "${local.bastion_ip}/32"
}

resource "aws_vpc_security_group_ingress_rule" "app_a_icmp" {
  security_group_id = aws_security_group.app_a.id
  description       = "ICMP echo request from App-B"
  ip_protocol       = "icmp"
  from_port         = 8 # ICMP type 8 (echo request)
  to_port           = 0 # ICMP code 0
  cidr_ipv4         = "${local.app_b_ip}/32"
}

resource "aws_vpc_security_group_ingress_rule" "app_b_ssh" {
  security_group_id = aws_security_group.app_b.id
  description       = "SSH from bastion private IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "${local.bastion_ip}/32"
}

resource "aws_vpc_security_group_ingress_rule" "app_b_icmp" {
  security_group_id = aws_security_group.app_b.id
  description       = "ICMP echo request from App-A"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
  cidr_ipv4         = "${local.app_a_ip}/32"
}

# OPTIONAL, TEST-ONLY (default off): lets App-A reach App-B on TCP/22 to test port reachability.
# Not part of the workbook design (App-B SSH is bastion-only). Remove after testing.
resource "aws_vpc_security_group_ingress_rule" "app_b_ssh_from_app_a_test" {
  count             = var.enable_app_b_ssh_from_app_a_test ? 1 : 0
  security_group_id = aws_security_group.app_b.id
  description       = "TEST ONLY: SSH from App-A private IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "${local.app_a_ip}/32"
}

# Workbook: keep default allow-all outbound. Terraform removes AWS's default, so recreate it.
resource "aws_vpc_security_group_egress_rule" "allow_all" {
  for_each = {
    bastion = aws_security_group.bastion.id
    app_a   = aws_security_group.app_a.id
    app_b   = aws_security_group.app_b.id
  }
  security_group_id = each.value
  description       = "Default allow-all outbound (per workbook)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------- Key pair (public key only) ----------------
resource "aws_key_pair" "lab" {
  key_name   = "ewb-lab"
  public_key = file(pathexpand(var.public_key_path))
  tags       = { Name = "ewb-lab" }
}

# ---------------- EC2 instances ----------------
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.a_public.id
  private_ip                  = local.bastion_ip
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.lab.key_name

  metadata_options {
    http_tokens = "required"
  }
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    tags                  = merge(local.tags, { Name = "ewb-bastion-root" })
  }
  tags       = { Name = "ewb-bastion" }
  depends_on = [aws_route.a_public_default]
}

resource "aws_instance" "app_a" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.a_private.id
  private_ip                  = local.app_a_ip
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.app_a.id]
  key_name                    = aws_key_pair.lab.key_name

  metadata_options {
    http_tokens = "required"
  }
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    tags                  = merge(local.tags, { Name = "ewb-app-a-root" })
  }
  tags = { Name = "ewb-app-a" }
}

resource "aws_instance" "app_b" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.b_private.id
  private_ip                  = local.app_b_ip
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.app_b.id]
  key_name                    = aws_key_pair.lab.key_name

  metadata_options {
    http_tokens = "required"
  }
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    tags                  = merge(local.tags, { Name = "ewb-app-b-root" })
  }
  tags = { Name = "ewb-app-b" }
}

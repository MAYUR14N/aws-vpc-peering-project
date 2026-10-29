# Setup guide

**Warning:** `terraform apply` creates billable resources. Use a dedicated lab account/Region. Running this configuration against an account that already contains the lab will try to create duplicates (names such as `ewb-lab` key pair and security groups must be unique).

## Prerequisites
Terraform >= 1.9, AWS CLI v2, OpenSSH client, an AWS identity that is **not** the root user (use an appropriately scoped identity; no IAM policy example is included because permissions depend on your account and workflow).

## Steps
1. Authenticate with `aws configure sso` (preferred) or a limited IAM user; verify with `aws sts get-caller-identity` (must not show `:root`).
2. Create a local key pair (private key stays outside the repo):
   `ssh-keygen -t rsa -b 4096 -f "$HOME\.ssh\ewb-lab"`
3. Find your public IPv4 (`https://checkip.amazonaws.com`) and set it as a /32.
4. `cd terraform; Copy-Item terraform.tfvars.example terraform.tfvars` and edit `student_name`, `bastion_allowed_cidr`, `aws_region` (default `us-east-1`), `public_key_path`.
5. `terraform fmt -check -recursive`, `terraform init`, `terraform validate`.
6. `terraform plan -out tfplan`; review for unexpected resources and any `0.0.0.0/0` SSH/ICMP rule.
7. Apply only after review. Optional baseline: deploy with `enable_peering = false`, capture the failed ping, then set `true`.

## SSH config (laptop)
Use `terraform output ssh_config_snippet` (ProxyJump through the bastion).

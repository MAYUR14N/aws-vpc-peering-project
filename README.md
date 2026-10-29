# AWS VPC Peering with Private EC2 Instances, Bastion Access and Failure Recovery

Two VPCs connected by VPC peering. Two application servers stay private (no public IPv4); a single bastion host in VPC A is the only SSH entry point. Built with Terraform in **us-east-1** for the EWB Courses AWS VPC Peering project.

## Objectives
- Non-overlapping VPC/subnet CIDRs and explicit route-table associations.
- Peering with routes in **both** directions.
- Inbound access limited to the lab hosts (SSH from bastion, ICMP between the apps).
- Show a baseline failure, successful two-way ping, and a controlled failure with recovery.

## Architecture
See [docs/architecture.md](docs/architecture.md) (Mermaid diagram).

| Resource | CIDR / IP |
|---|---|
| VPC A `ewb-vpc-a` | 10.10.0.0/16 |
| Public subnet `ewb-a-public` | 10.10.1.0/24 (bastion 10.10.1.10) |
| Private subnet `ewb-a-private` | 10.10.2.0/24 (App-A 10.10.2.10) |
| VPC B `ewb-vpc-b` | 10.20.0.0/16 (no Internet Gateway) |
| Private subnet `ewb-b-private` | 10.20.1.0/24 (App-B 10.20.1.10) |

AWS services: VPC, subnets, Internet Gateway, route tables, VPC peering, security groups, EC2 (Amazon Linux 2023), EC2 key pair. No NAT gateway, load balancer or other services.

## Repository layout
```
terraform/   main.tf variables.tf outputs.tf providers.tf versions.tf terraform.tfvars.example
docs/        architecture, setup, testing, troubleshooting, security
screenshots/ evidence index (images added only when genuine)
```

## Important: source code versus the live AWS environment

This repository is a sanitized Terraform source package based on the supplied project files and documented test history. The live environment was also changed manually during troubleshooting. Therefore, **do not assume this source is byte-for-byte identical to the configuration/state that created every currently running AWS resource**. See [docs/drift.md](docs/drift.md) before using it against an existing account.

PowerShell was used to run Terraform and AWS CLI commands; PowerShell command history alone is not the Terraform source. The `.tf` files in `terraform/` are the source files to review and validate. Do not apply them to the existing lab deployment without reconciling its Terraform state and manually changed rules.

## Project status (what has and has not been checked)
| Item | Status |
|---|---|
| Live deployment in us-east-1 | Reported by the author (not re-verified by the documentation process) |
| Connectivity tests (ping, TCP/22, ICMP failure/recovery) | Reported by the author; screenshots pending - see [testing](docs/testing-and-validation.md) |
| `terraform fmt` / `init` / `validate` on this final source | **PENDING - not run in this environment; run locally before claiming validation** |
| Security scanner / secret scan | See [docs/security.md](docs/security.md) |
| Live state vs this code | Known drift, see [docs/drift.md](docs/drift.md) |

Validation result (fill in after running): `fmt: ___  init: ___  validate: ___`

## Validation only (does not touch AWS)
```powershell
cd terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```
## Deploying a fresh copy (separate account/Region or after cleanup)
```powershell
Copy-Item terraform.tfvars.example terraform.tfvars   # edit; never commit
terraform plan -out tfplan                            # review, then apply only if correct
```
> `apply` creates billable resources (EC2, EBS, public IPv4). Do **not** apply this code to the existing lab deployment: resources already exist, and manual changes are not reflected in state ([docs/drift.md](docs/drift.md)).

## Verified tests
Results are **reported by the author from the live lab**; see [docs/testing-and-validation.md](docs/testing-and-validation.md).

## Documentation
[Architecture](docs/architecture.md) · [Setup](docs/setup-guide.md) · [Testing](docs/testing-and-validation.md) · [Troubleshooting](docs/troubleshooting.md) · [Drift](docs/drift.md) · [Security](docs/security.md)

## Limitations / future work
- Bastion SSH source is a single /32 and must be updated when the client IP changes (e.g. mobile hotspot).
- Outbound rules are allow-all (workbook default); root volumes are not explicitly encrypted; no VPC Flow Logs in Terraform; VPC default security groups are not locked down. These are scanner-style findings noted in [docs/security.md](docs/security.md), intentionally not changed to avoid replacing working infrastructure.
- Private instances have no internet egress by design (no NAT).

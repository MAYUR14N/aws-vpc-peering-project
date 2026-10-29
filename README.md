# AWS VPC Peering with Private EC2 Instances and Bastion Access

A Terraform-based AWS networking project that connects two non-overlapping Virtual Private Clouds (VPCs) through VPC peering. The design keeps both application instances on private IPv4 addresses and uses a single bastion host in VPC A as the intended SSH entry point. The project follows the EWB Courses AWS VPC Peering student workbook and targets **`us-east-1`**.

> **Important — existing AWS environment and Terraform drift:** The live lab was modified manually during troubleshooting. This repository contains the Terraform source package and supporting documentation, but it is not guaranteed to represent every resource or rule currently present in the live AWS environment. Read [Terraform drift and manual changes](docs/drift.md) before using this code with an existing account. Do not run `terraform apply` or `terraform destroy` against the existing lab unless its Terraform state and all manual changes have first been reconciled.

## Project objectives

- Plan non-overlapping VPC and subnet CIDR ranges.
- Create public and private subnets with explicit route-table associations.
- Establish VPC peering and configure routes in both directions.
- Keep App-A and App-B private, without public IPv4 addresses.
- Restrict inbound SSH and ICMP access to the required lab hosts.
- Test private connectivity and demonstrate a controlled ICMP failure followed by recovery.

## Architecture and IP plan

| Resource | IPv4 CIDR or address | Purpose |
|---|---|---|
| VPC A — `ewb-vpc-a` | `10.10.0.0/16` | Bastion and App-A network |
| Public subnet — `ewb-a-public` | `10.10.1.0/24` | Bastion subnet |
| Bastion — `ewb-bastion` | Private IP `10.10.1.10` plus a public IPv4 address | Intended SSH entry point |
| Private subnet — `ewb-a-private` | `10.10.2.0/24` | App-A subnet |
| App-A — `ewb-app-a` | `10.10.2.10` | Private workload in VPC A |
| VPC B — `ewb-vpc-b` | `10.20.0.0/16` | Private workload network; no Internet Gateway |
| Private subnet — `ewb-b-private` | `10.20.1.0/24` | App-B subnet |
| App-B — `ewb-app-b` | `10.20.1.10` | Private workload in VPC B |
| Peering connection — `ewb-a-b-peer` | AWS-assigned `pcx-...` identifier | Private routing between the VPCs |

The diagram and design rationale are documented in [docs/architecture.md](docs/architecture.md).

### Traffic flow

- **Administration:** Laptop → bastion public IPv4 → App-A or App-B private IPv4, using SSH ProxyJump.
- **Application connectivity:** App-A ↔ App-B over private IPv4 through the VPC peering connection.
- **Routes:** App-A's subnet route table sends `10.20.0.0/16` to the peering connection. App-B's subnet route table sends `10.10.0.0/16` to the peering connection. VPC A's public route table also needs a route to VPC B so the bastion can reach App-B through ProxyJump.
- **Internet access:** VPC A has an Internet Gateway for the bastion. VPC B has no Internet Gateway, and the design does not create a NAT Gateway. VPC peering does not provide VPC B with Internet access through VPC A's Internet Gateway.

## Security design

- Bastion inbound SSH (TCP/22) is restricted to the administrator's current public IPv4 address as a single `/32`.
- App-A and App-B inbound SSH is restricted to the bastion's private IPv4 address.
- ICMP Echo Request is allowed only from the other application's private IPv4 address.
- The optional App-A-to-App-B TCP/22 ingress rule is **test-only and disabled by default**. It is not part of the intended bastion-only SSH design and can create a lateral-movement path if enabled.
- IMDSv2 is required by the EC2 resources. Terraform reads a public key file; the private key must remain local and must never be committed.

Known hardening gaps—including allow-all egress, the absence of Terraform-managed VPC Flow Logs, default security groups not explicitly restricted, and root volumes not explicitly configured as encrypted—are documented in [docs/security.md](docs/security.md). This educational lab is not claimed to be production-hardened.

## Repository structure

```text
terraform/   Terraform resources, variables, outputs, provider constraints and lock file
 docs/       Architecture, setup, test matrix, troubleshooting, security and drift notes
screenshots/ Evidence index; actual test screenshots still need to be added
```

## Validation and project status

The following Terraform checks were run locally on the prepared source package. These checks validate the Terraform configuration; they do not prove that the source exactly matches the live AWS resources.

| Check | Status | Scope / note |
|---|---|---|
| `terraform fmt -check -recursive` | **Passed** | Prepared source package |
| `terraform init -backend=false` | **Passed** | Initialized providers without configuring a backend |
| `terraform validate` | **Passed** | Prepared source package |
| Checkov | **Reported result: 79 passed, 15 failed, 0 parsing errors** | Offline Checkov 3.4.0 scan of `terraform/`; findings are detailed in [docs/security.md](docs/security.md) |
| Live peering and connectivity | **Reported successful by the author** | Not independently re-run while preparing this README |
| Baseline ping before peering/routes | **Pending / unknown** | Confirm whether the failure was captured |
| Genuine screenshots and terminal evidence | **Pending** | `screenshots/` currently contains an evidence index, not the actual screenshots |
| Final workbook report PDF and cleanup evidence | **Pending** | See the deliverables section below |

Refer to [docs/testing-and-validation.md](docs/testing-and-validation.md) for individual tests and a distinction between reported observations, expected results and evidence still pending.

## Validate the Terraform source

Run from the repository root in Windows PowerShell. These commands do not create or modify AWS resources:

```powershell
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform validate
```

Repeat these checks after changing Terraform files. Do not describe a live connectivity test or deployment as independently verified merely because `terraform validate` passed.

## Deploying a fresh copy

Use these steps only for a **separate, clean lab deployment**—not for the existing lab environment until state and drift have been reconciled.

```powershell
Copy-Item .\terraform\terraform.tfvars.example .\terraform\terraform.tfvars
# Edit .\terraform\terraform.tfvars and replace every placeholder.
terraform -chdir=terraform plan -out=tfplan
# Review the plan, resource replacements and cost implications before applying.
```

Applying can create billable EC2 instances, EBS volumes and a public IPv4 address. Do not apply automatically. Review [docs/setup-guide.md](docs/setup-guide.md), [docs/security.md](docs/security.md) and [docs/drift.md](docs/drift.md) first. Never commit `terraform.tfvars`, Terraform state files, plan files, credentials or private keys.

## EWB workbook submission: remaining deliverables

The repository documents the architecture, IP plan, Terraform configuration, routing, security rules, troubleshooting and test procedures. However, **the workbook submission is not yet fully evidenced by the repository**. The workbook checklist and marking rubric are on page 13 of the supplied EWB Courses workbook; cleanup steps are on page 14.

Before treating the submission as complete:

1. Add the actual resource inventory to your project report, including VPC, subnet, route-table, peering and instance IDs. Do not include credentials or private keys.
2. Capture genuine screenshots for the active peering connection, all three route tables and their subnet associations, security-group ingress, both ping directions, SSH to App-B through the bastion, the controlled ICMP failure and recovery, and cleanup.
3. Confirm whether you captured the baseline ping failure before establishing peering and peer routes.
4. Prepare the required report PDF named `YourName_EWB_VPC_Peering.pdf`. Include your name, batch, project title, Region, completion date, architecture/inventory, evidence captions, forward- and return-path explanation, cleanup evidence and a short reflection.
5. Ensure both application instances have no public IPv4 addresses and label each screenshot with the host, test and result.

A README and Terraform source code do not replace the required report PDF and genuine execution evidence.

## Documentation

- [Architecture](docs/architecture.md)
- [Setup guide](docs/setup-guide.md)
- [Testing and validation](docs/testing-and-validation.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Terraform drift and manual changes](docs/drift.md)
- [Security notes](docs/security.md)

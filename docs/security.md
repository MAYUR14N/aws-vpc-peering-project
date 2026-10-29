# Security Review and Operational Notes

This document summarizes the security controls represented in the Terraform source, recorded scanner results, known gaps, and differences between the source code and the live AWS environment. It does not claim that the environment has been independently security-tested or hardened for production.

## 1. Secrets and Terraform State

Never commit real variable files, Terraform state, saved plans, credentials, private keys, or environment files. Keep the following out of Git:

- `terraform.tfvars` and other real `*.tfvars` files
- `*.tfstate` and `*.tfstate.*`
- `.terraform/` and saved plan files such as `tfplan`
- Private keys such as `*.pem`, `*.ppk`, and `*.key`
- Credentials, access tokens, and `.env` files

Terraform state and plan files can contain sensitive information. Protect them and restrict access.

The `.gitignore` file helps prevent accidental additions but does not remove files already tracked by Git. Review tracked files using `git ls-files`.

Terraform reads a public SSH key from the configured public-key path. Keep the corresponding private key on your own machine. Never commit or upload the private key.

## 2. Intended Access Controls

| Control | Intended configuration | Security purpose |
|---|---|---|
| Bastion SSH | TCP/22 from the administrator's current public IPv4 /32 only | Restricts the Internet-facing SSH entry point |
| App-A SSH | TCP/22 from the bastion private IP | Keeps administration on the bastion path |
| App-B SSH | TCP/22 from the bastion private IP | Preserves bastion-based access across VPC peering |
| Inter-application ICMP | Echo Request from the other application host's private IP | Supports connectivity tests |
| Application public addresses | App-A and App-B have no public IPv4 addresses | Reduces direct Internet exposure |
| EC2 metadata | IMDSv2 tokens are required | Improves instance-metadata access protection |
| IAM access | Use least-privilege identities and MFA/SSO; avoid root access keys | Reduces credential-related risk |

Never expose bastion SSH to `0.0.0.0/0`. Update the allowed /32 when your public IP changes, then verify the security-group rule.

## 3. Recorded Checkov Scan Results

The project records an offline Checkov 3.4.0 scan of the `terraform/` directory.

| Result | Recorded count |
|---|---:|
| Passed | 79 |
| Failed | 15 |
| Parsing errors | 0 |

Recorded findings include:

- EBS optimization and detailed monitoring checks for the three EC2 instances.
- A public IPv4 address on the bastion, which is intentional for this architecture.
- No VPC Flow Logs managed by this Terraform source for the two VPCs.
- Default VPC security groups not explicitly restricted by this configuration.
- No IAM instance profile configured for the three EC2 instances.
- An informational finding concerning availability-zone data-source selection.

The recorded scan did not report hardcoded secrets or inbound SSH/ICMP rules open to `0.0.0.0/0`. These are previously recorded scan results; the scan was not rerun during this documentation update.

Checkov is a static security scanner. It does not replace Terraform validation or inspection of the live AWS environment.

## 4. Known Security Gaps and Trade-Offs

| Finding | Implication | Recommended consideration |
|---|---|---|
| Allow-all security-group egress | Outbound rules permit traffic to `0.0.0.0/0`; actual reachability also depends on routing and other controls | Restrict egress after identifying and testing required traffic |
| Root EBS volumes not explicitly configured as encrypted | The Terraform source does not explicitly set root-volume encryption | Plan encryption for a new deployment or a carefully reviewed migration |
| Default security groups not explicitly restricted | This Terraform source does not manage their rules | Review and remove unnecessary rules where safe |
| VPC Flow Logs not managed by this source | Project notes report that diagnostic Flow Logs were created manually | Plan logging, retention, permissions, destination, and cost |
| No EC2 IAM instance profile | The source does not define an instance role for these instances | Add least-privilege roles when workloads require AWS API access |
| Public bastion address | The bastion is the intended Internet-facing administration point | Restrict SSH to a trusted /32; consider managed access for future hardening |
| Monitoring and EBS optimization findings | The recorded scanner flagged these checks for the three instances | Evaluate operational value, supported instance types, and cost |

These items are documented rather than silently changed because modifications can affect a working deployment. This beginner lab is not presented as a production security baseline.

## 5. App-A-to-App-B SSH Test Rule

The intended workbook design permits SSH to App-B only from the bastion. Terraform contains an optional test-only TCP/22 rule allowing App-A to reach App-B. The variable `enable_app_b_ssh_from_app_a_test` defaults to `false`.

Enabling this rule allows software running on App-A to attempt SSH connections to App-B directly over peering. If App-A were compromised, this creates an additional lateral-movement path that bypasses the bastion-only design.

Restricting the rule to one /32 and one port reduces its scope but does not eliminate the risk.

Project notes report that an equivalent rule was added manually to the live AWS environment for a TCP/22 reachability test. A default-off Terraform variable does not prove that the manually created rule has been removed.

Inspect the actual App-B security group and Terraform state before changing the rule. Remove the temporary rule after testing if it is no longer needed. Do not blindly apply this source to an environment whose state and manual changes have not been reconciled.

See [drift.md](drift.md) for details of known manual changes, including the restored ICMP rule and diagnostic Flow Log, CloudWatch, and IAM resources.

## 6. Safe Cleanup Procedure

1. Save genuine screenshots and test results before deleting resources.
2. Identify project resources using tags, resource names, VPC IDs, subnet IDs, EC2 instance IDs, security groups, and the peering ID.
3. Inspect Terraform state and create a destroy plan only after confirming it contains exclusively the resources intended for removal.
4. Because source/state drift and manual changes are known, do not run `terraform destroy` against the existing lab until the state has been reconciled and the deletion scope is understood.
5. Handle manually created resources outside Terraform state separately and deliberately.
6. After cleanup, verify EC2 instances, EBS volumes and snapshots, public IPv4 allocations, key pairs, security groups, peering connections, route tables, subnets, the Internet Gateway, and VPCs in the AWS Console.
7. Check AWS Billing for remaining charges. Billing information may be delayed.

Cleanup commands can delete resources and data. Confirm ownership and scope before removing anything from a shared or existing environment.
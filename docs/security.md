# Security notes

## Secrets and state
Never commit: `terraform.tfvars`, `*.tfstate*`, `.terraform/`, private keys, credentials. Terraform state can contain sensitive values. Only the **public** key is read by Terraform; the private key stays local. `.gitignore` does not untrack files already committed; check with `git ls-files`.

## Access control
- Bastion SSH is limited to one /32 (never `0.0.0.0/0`). Update it when your IP changes.
- App instances have no public IPv4; SSH only from the bastion private IP.
- Use a non-root IAM identity with MFA/SSO; do not use root access keys.
- IMDSv2 is required on all instances.

## Scan results (actually run, Checkov 3.4.0, offline, `terraform/` only)
79 passed, 15 failed, 0 parsing errors. Failures: EC2 not EBS-optimized and no detailed monitoring (3 instances each, small cost/feature items), bastion has a public IP (by design), no VPC Flow Logs (2 VPCs), default security groups not restricted (2 VPCs), no IAM instance profile (3 instances), AZ data-source pinning (informational). None indicates a hardcoded secret or an open `0.0.0.0/0` SSH/ICMP rule. Checkov is not Terraform validation and does not replace `terraform validate`.

## Known findings (not changed, to avoid replacing working infrastructure)
| Finding | Note |
|---|---|
| Egress allow-all on security groups | Workbook default for the beginner lab |
| Root EBS volumes not explicitly encrypted | Setting `encrypted = true` forces instance replacement |
| VPC default security groups not restricted | Could add `aws_default_security_group` with no rules |
| No VPC Flow Logs in Terraform | A flow log was created manually for diagnostics |

## Drift and manual changes
See [drift.md](drift.md). In short: an extra App-B TCP/22 rule (from App-A), a manually restored ICMP rule, and diagnostic Flow Log/CloudWatch/IAM resources exist in AWS outside Terraform.

## Security implications of the App-A to App-B SSH rule
The workbook design allows SSH to App-B only from the bastion. Allowing App-A (10.10.2.10/32) as well lets anything running on App-A attempt SSH to App-B, so a compromised App-A gains a lateral-movement path into VPC B that bypasses the bastion choke point. The scope is narrow (one /32, one port, authentication still required), but it is a deviation. Hence it is modeled only as an optional, default-off test variable and should be removed after testing.

## Cleanup
Save all evidence first. Review `terraform plan -destroy` and confirm only lab resources are listed, then destroy, then verify in the Console (instances, volumes, VPCs, peering, key pair) and check Billing. Remove the manually created diagnostic resources separately.

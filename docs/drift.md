# Drift between live AWS and this Terraform source

No Terraform state was read, modified, imported or removed, and nothing was applied, while preparing this document. Findings are inferred from how the code is written plus the author's account of manual changes; confirm with the read-only checks below.

## 1. Manually restored ICMP rule (App-B, echo request from 10.10.2.10/32)
- Terraform manages it as `aws_vpc_security_group_ingress_rule.app_b_icmp`. The AWS provider tracks that resource by the **security-group-rule ID** AWS assigned when it was created.
- During the controlled failure the rule was deleted in AWS. If it was re-created in the Console/CLI, the new rule has a **new ID**, so state still points at the deleted one.
- Likely consequences: `terraform plan` (which refreshes) reports the old rule as missing and proposes to **create** it; `apply` would then fail with a duplicate-permission error because an identical rule already exists. If instead the rule was restored via `terraform apply`, there is no drift.
- Resolution options (not performed; decide after reading a plan): (a) leave as is and never apply to this deployment; (b) after approval, remove that rule from state and import the live rule ID; (c) delete the live rule and let Terraform recreate it, accepting a brief ICMP outage.

## 2. Extra App-B TCP/22 rule from App-A (10.10.2.10/32)
- Exists in AWS (test-only), was **not** in the original code. Because rules are separate resources and the groups have no inline rules, Terraform does **not** detect extra rules: a plan shows no change for it.
- Now represented as `app_b_ssh_from_app_a_test`, default **off**. Enabling it against the live deployment would try to create a duplicate. Keep it off there; on a fresh deployment enable it only for the test and then disable it.
- Recommended: remove the live rule after evidence is saved (a CHANGE to AWS, done by you via Console/CLI).

## 3. Resources created outside Terraform
VPC Flow Log, CloudWatch log group, IAM role and policy for flow logs. `terraform destroy` will not remove them; delete them separately at cleanup (they incur small ongoing cost).

## 4. Value differences
`terraform.tfvars` (not published) held the live `us-east-1` values and the then-current /32. The published defaults now use `us-east-1`; `bastion_allowed_cidr` remains a required input.

## Read-only checks (safe; do not change AWS)
```powershell
aws ec2 describe-security-group-rules --region us-east-1 --filters Name=group-id,Values=<app-b-sg-id> --output table
terraform plan -refresh-only   # contacts AWS read-only; proposes only state refresh. Run in your WORKING folder, review, do NOT apply.
```

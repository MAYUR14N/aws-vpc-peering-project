# Troubleshooting record

## Symptom
SSH from a Windows laptop (mobile hotspot) to the bastion's public IP: `Connection timed out` on TCP 22, before any key exchange.

## Evidence gathered (facts)
- Instance running, status checks passing; console log showed network up and the key installed.
- IGW attached; public route table had the default route; peering active.
- Reachability Analyzer found a *modeled* path (does not prove real packets arrive).
- Outbound TCP 22 from the laptop to another host (GitHub) succeeded.
- The bastion security group allowed an **older** hotspot IP; the laptop's current public IP differed. The rule was updated via Terraform (`bastion_allowed_cidr`, 1 change, 0 add/destroy).
- A VPC Flow Log (CloudWatch) was added to the bastion ENI to see whether SSH packets arrive. Unsolicited internet scan traffic was visible as `REJECT`, showing the ENI is internet-reachable.

## Root cause and final fix
**[Author to complete]** Record what finally made SSH work (e.g. updated source IP, different network, or other) and the evidence. Not stated in the material available when this document was written, so it is deliberately not guessed.

## Lessons
- Mobile hotspots change public IPs; a /32 rule goes stale.
- The public IP reported by a web service may differ from what AWS sees on carrier-grade NAT.
- Security-group drops are silent, so a timeout usually means "dropped", while "refused" means the host answered.
- Reachability Analyzer and "Active" peering do not prove traffic flows; test end to end.
- Separate Terraform rule resources do **not** detect extra rules added by hand (see security.md).

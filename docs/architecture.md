# Architecture

```mermaid
flowchart TB
  L["Laptop (SSH client)"] -- "TCP 22 from allowed /32 only" --> IGW["Internet Gateway ewb-igw-a"]
  subgraph A["VPC A  ewb-vpc-a  10.10.0.0/16"]
    direction TB
    subgraph PUB["Public subnet 10.10.1.0/24  (rt: ewb-rt-a-public)"]
      BAS["ewb-bastion 10.10.1.10 + public IPv4"]
    end
    subgraph PRV["Private subnet 10.10.2.0/24  (rt: ewb-rt-a-private)"]
      APA["ewb-app-a 10.10.2.10"]
    end
  end
  subgraph B["VPC B  ewb-vpc-b  10.20.0.0/16  (no IGW)"]
    subgraph PRB["Private subnet 10.20.1.0/24  (rt: ewb-rt-b-private)"]
      APB["ewb-app-b 10.20.1.10"]
    end
  end
  IGW --> BAS
  BAS -- "SSH (ProxyJump), local route" --> APA
  BAS -- "SSH via peering" --> APB
  APA <-- "ICMP / TCP via ewb-a-b-peer" --> APB
```

## Route tables
| Table | Destination | Target |
|---|---|---|
| ewb-rt-a-public | 10.10.0.0/16 | local |
| | 0.0.0.0/0 | Internet Gateway |
| | 10.20.0.0/16 | peering connection |
| ewb-rt-a-private | 10.10.0.0/16 | local |
| | 10.20.0.0/16 | peering connection |
| ewb-rt-b-private | 10.20.0.0/16 | local |
| | 10.10.0.0/16 | peering connection |

## Inbound security rules (as defined in Terraform)
| Security group | Rule | Source |
|---|---|---|
| ewb-sg-bastion | TCP 22 | operator public IPv4 /32 (variable) |
| ewb-sg-app-a | TCP 22 | 10.10.1.10/32 (bastion) |
| ewb-sg-app-a | ICMP echo request | 10.20.1.10/32 (App-B) |
| ewb-sg-app-b | TCP 22 | 10.10.1.10/32 (bastion) |
| ewb-sg-app-b | ICMP echo request | 10.10.2.10/32 (App-A) |
| ewb-sg-app-b | TCP 22 from 10.10.2.10/32 (App-A) | **Optional, test-only**, off by default (`enable_app_b_ssh_from_app_a_test`); exists manually in the live lab |

Peering is non-transitive and gives VPC B no internet access through VPC A. Security groups are stateful; default network ACLs are used.

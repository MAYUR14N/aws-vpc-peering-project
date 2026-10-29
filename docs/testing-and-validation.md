# Testing and validation

**Status key:** *Reported* = observed by the author in the live lab and **not re-run during documentation**. *Pending* = screenshot or evidence not yet attached. Nothing here was re-executed by the documentation process.

| # | Test | Purpose | Procedure | Expected | Observed | Status |
|---|---|---|---|---|---|---|
| 1 | Peering active | Link established | Console/CLI: peering state | `active` | Active (reported) | Reported; screenshot 01 pending |
| 2 | Cross-VPC routes | Both directions | Inspect private route tables | A: 10.20/16 → pcx; B: 10.10/16 → pcx | Present (reported) | Reported; screenshot 02 pending |
| 3 | Instance status | Healthy hosts | EC2 status checks | 2/2 pass | Pass (reported for bastion) | Partly reported; screenshot 03 pending |
| 4 | Bastion SSH | Admin path | `ssh ewb-bastion`, then App-A / App-B | Shell on each | Worked (reported) | Reported; screenshot 04 pending |
| 5 | App-A → App-B ping | Forward path | `ping -c 4 10.20.1.10` on App-A | 4/4, 0% loss | Success (reported) | Reported; screenshot 05 pending |
| 6 | App-B → App-A ping | Return path | `ping -c 4 10.10.2.10` on App-B | 4/4, 0% loss | Success (reported) | Reported; screenshot 06 pending |
| 7 | TCP/22 App-A → App-B | Port reachability only | TCP connect test to 10.20.1.10:22 (exact tool: [author to fill]) | Port open | Reachable (reported) | Reported; screenshot 09 pending. The App-B TCP/22 rule from App-A used for this was added manually and is test-only ([drift](drift.md)). **A full SSH login App-A → App-B was not tested.** |
| 8 | Controlled ICMP failure | Show SG effect | Remove only App-B ICMP rule from 10.10.2.10/32; ping from App-A | 100% loss | Failure (reported) | Reported; screenshot 07 pending |
| 9 | Recovery | Restore rule | Re-add the exact ICMP rule; ping again | 4/4, 0% loss | 4/4, 0% loss (reported) | Reported; screenshot 08 pending |
| 10 | Isolation | No public IP on apps | Instance details | Empty public IPv4 | Confirmed earlier (reported) | Reported |
| 11 | Baseline before peering | Negative test | Ping before peering/routes | No replies | [author to state whether captured] | Pending / unknown |

Terraform code checks (`fmt`, `validate`, scanners) are **NOT RUN** by the documentation process; results must be added after you run them locally.

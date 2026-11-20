# Azure Spoke-to-Spoke Peering Lab

A small, low-cost Azure lab: two VNets peered directly, one Ubuntu VM in each.
Built for learning, not production hardening.

## Topology

```
 your PC --SSH--> [vm1-spoke1] 10.1.0.0/24  <--peering-->  [vm2-spoke2] 10.2.0.0/24
                  vnet-spoke1 10.1.0.0/16                   vnet-spoke2 10.2.0.0/16
                  (public IP)                               (no public IP)
```

- Public IP only on spoke1, with SSH allowed from your own IP only
- Ubuntu 24.04 LTS, `Standard_B2s`, Standard SSD, SSH key authentication
- NIC, public IP and OS disk are deleted with the VM

## Prerequisites

- Azure CLI (`az login`) with Bicep (`az bicep install`)
- An SSH key pair: `ssh-keygen -t ed25519 -f $HOME\.ssh\azure_lab`

## Deploy

1. Copy `main.parameters.example.json` to `main.parameters.json` and fill in:
   - `sshPublicKey`: the contents of `azure_lab.pub`
   - `allowedSshSource`: your public IP with `/32`, e.g. `203.0.113.5/32`
2. Run:

```powershell
az group create --name rg-spoke-lab --location eastus
az deployment group create --resource-group rg-spoke-lab --template-file main.bicep --parameters main.parameters.json
```

`main.parameters.json` is in `.gitignore`. Never commit it.

## Test

```powershell
ssh -i $HOME\.ssh\azure_lab Demouser@<spoke1-public-ip>
```

Then from inside spoke1:

```bash
ping -c 4 10.2.0.4
```

Check spoke2's real private IP on its Overview page if the ping gets no reply. To reach spoke2 directly from your PC, jump through spoke1:

```powershell
ssh -J Demouser@<spoke1-public-ip> -i $HOME\.ssh\azure_lab Demouser@10.2.0.4
```

## Experiments

- **ICMP deny:** add an inbound Deny rule for ICMP at priority 101 on the spoke2 NSG. Ping fails, SSH still works.
- **Network Watcher:** run **IP flow verify** and **Next hop** from spoke1 to spoke2's IP. Next hop should show *VNet peering*, and IP flow verify names the rule allowing or denying the traffic.
- **Half a peering:** delete one side of the peering and watch the status change and traffic stop.

## Cost and teardown

VNets and peering are cheap. The main costs are the VMs, disks and the public IP. Deallocate VMs when not in use. To remove everything:

```powershell
az group delete --name rg-spoke-lab --yes --no-wait
```

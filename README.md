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
- Ubuntu 24.04 LTS, Standard SSD, SSH key authentication
- Small B-series VMs. The size is set by the `vmSize` parameter (default `Standard_B2s`)
- NIC, public IP and OS disk are deleted with the VM

## Prerequisites

- Azure CLI (`az login`) with Bicep (`az bicep install`)
- An SSH key pair: `ssh-keygen -t ed25519 -f $HOME\.ssh\azure_lab`

Keep the private key (`azure_lab`) outside this repo folder. Only the `.pub` file is ever used here.

## Deploy

1. Copy `main.parameters.example.json` to `main.parameters.json` and fill in:
   - `sshPublicKey`: the contents of `azure_lab.pub`
   - `allowedSshSource`: your public **IPv4** address with `/32`, e.g. `203.0.113.5/32`
2. Check which VM sizes are open to your subscription in your region. Availability varies, and a restricted size makes the deployment fail (tested in Sweden Central):

```powershell
az vm list-skus --location <region> --size Standard_B --output table
```

Pick a 2 vCPU size whose Restrictions column says `None`.

3. Run:

```powershell
az group create --name rg-spoke-lab --location <region>
az deployment group create --resource-group rg-spoke-lab --template-file main.bicep --parameters main.parameters.json vmSize=<size>
```

`main.parameters.json` is in `.gitignore`. Never commit it.

## Test

Get the spoke1 public IP from the portal, or from the deployment output:

```powershell
az deployment group show --resource-group rg-spoke-lab --name main --query properties.outputs
```

Then connect:

```powershell
ssh -i $HOME\.ssh\azure_lab Demouser@<spoke1-public-ip>
```

From inside spoke1:

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

## Troubleshooting

- **`SkuNotAvailable` on deploy:** the VM size is restricted in that region for your subscription. Re-run the `az vm list-skus` check above, pick an unrestricted size, and pass it with `vmSize=<size>`.
- **SSH times out:** `allowedSshSource` must be your public **IPv4** address with `/32` (for example from `https://api.ipify.org`), not an IPv6 address. Your IP can change, so update the value and redeploy if it does.

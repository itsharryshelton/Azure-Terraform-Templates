# Azure Web VM Terraform Template

This repository contains a Terraform template to deploy a single, security-hardened Windows Virtual Machine in Microsoft Azure with a Virtual Network

It's designed to be a secure starting point for a standalone web server or application server, with a "deny-all" firewall policy that only permits specific traffic.

## Architecture Overview

This template deploys the following infrastructure into a single resource group (`rg-prod-001`):

1.  **Network:** A Virtual Network (`vnet-prod-uksouth-001`) and one subnet (`snet-prod-uksouth-001`).
2.  **Network Security Group (NSG):** A highly restrictive NSG (`nsg-prod-uksouth-001`) that is applied to the subnet.
3.  **Virtual Machine (VM):** A single Windows Server 2025 VM.
4.  **Network Interface (NIC):** A NIC for the VM with a **static private IP** of `10.0.1.10`.

**This VM does not have a Public IP address.** It is only accessible via its private IP from other resources in the VNet or from trusted external IPs (like an RMM tool) defined in the NSG.

### Security Policy

The NSG is configured with a **deny-by-default** posture. All inbound and outbound traffic is **denied** *except* for the following specific rules:

**Inbound Rules:**
* **DENY:** All RDP (port 3389) from any source.
* **ALLOW:** HTTPS (port 443) from the `Internet`.
* **ALLOW:** All traffic from a list of specific RMM (Remote Management) tool IPs.

**Outbound Rules:**
* **ALLOW:** Outbound web traffic (TCP ports 80 & 443) to the internet.
* **ALLOW:** All outbound traffic *to* the specific RMM tool IPs.

---

## How to Use This Template

Follow these steps to customize and deploy your infrastructure.

### 1. Prerequisites

* An active Azure Subscription.
* [Terraform](https://developer.hashicorp.com/terraform/downloads) (v1.0 or later) installed.
* Azure CLI installed and authenticated (`az login`).

### 2. Configuration (What You MUST Edit)

This template uses a mix of variables and hard-coded values. You **must** edit the `default` values in `main.tf` or provide your own `.tfvars` file.

#### Critical NSG Rule (In-Code Edit)

You **must** change the placeholder IPs for your RMM tool. Edit the `azurerm_network_security_group.nsg_prod` resource:

> ```hcl
>   security_rule {
>     name                       = "Allow_RMM_Inbound"
>     ...
>     source_address_prefixes    = ["1.2.3.4", "4.3.2.1"] # <-- EDIT THESE IPs
>   }
> ```
>
> You must also edit the outbound rule `Allow_RMM_Oubound` to match your RMM tool's public IPs.

#### VM Variables (Edit Defaults)

| Variable | `main.tf` Default | Description |
| :--- | :--- | :--- |
| `admin_password` | `"Password1234!"` | **Change this** to a complex local admin password. |
| `admin_username` | `"azureadmin"` | (Optional) Change the local admin username. |
| `vm_name` | `"xx-vm-app-001"` | **Change this** to your desired VM name. |
| `vm_size` | `"Standard_B2ms"` | (Optional) Change the VM size/SKU. |

#### Hard-Coded Naming (In-Code Edit)

The following resources have hard-coded names. You must edit them directly in the `main.tf` file if you want to change them:
* `azurerm_resource_group.rg_prod` (name: "rg-prod-001")
* `azurerm_virtual_network.vnet_prod` (name: "vnet-prod-uksouth-001")
* `azurerm_subnet.snet_prod` (name: "snet-prod-uksouth-001")
* `azurerm_network_security_group.nsg_prod` (name: "nsg-prod-uksouth-001")

#### IP Addressing (In-Code Edit)
The VM's private IP is hard-coded. To change it, edit the `azurerm_network_interface.nic_dc` resource:

> ```hcl
>   ip_configuration {
>     ...
>     private_ip_address            = "10.0.1.10" # <-- EDIT THIS IP
>   }
> ```

### 3. Deployment Steps

Once you have saved your configuration changes, run the standard Terraform commands:

```bash
# 1. Initialize the Terraform providers
terraform init

# 2. Review the plan to see what will be created
terraform plan

# 3. Apply the configuration and build the infrastructure
terraform apply

# Secure Azure Hub-Spoke Foundation Terraform Template

This template is designed to deploy a secure and scalable [Hub-Spoke network architecture](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke) in Microsoft Azure.

It's designed as a robust starting point for production workloads, complete with network segmentation, secure connectivity to an on-premises network, and private-only resources.



## Architecture Overview

This template deploys the following infrastructure:

1.  **Hub Network:** A central VNet (`vnet-hub`) that acts as the primary connectivity point.
    * **VPN Gateway:** A Route-Based VPN Gateway (`azurerm_virtual_network_gateway`) to connect your Azure environment to an on-premises office via a **Site-to-Site (S2S) IPsec tunnel**.
    * **Gateway Subnet:** The required `GatewaySubnet` for the VPN.
    * **Local Network Gateway:** A resource (`azurerm_local_network_gateway`) that represents your on-premises office firewall/VPN device.

2.  **Spoke Network:** An isolated VNet (`vnet-spoke`) designed to host your application workloads.
    * **Application Subnet:** A subnet (`snet-prod`) to host your virtual machines.
    * **NAT Gateway:** A `azurerm_nat_gateway` with a static public IP is attached to the app subnet. This provides secure, controlled **outbound-only** internet access for the VMs, without exposing them to inbound internet traffic.
    * **Network Security Group (NSG):** A pre-configured NSG (`nsg-prod`) to filter traffic to your VMs.

3.  **VNet Peering:**
    * The Hub and Spoke VNets are connected using `azurerm_virtual_network_peering`.
    * **Gateway Transit** is enabled, allowing VMs in the Spoke network to communicate with your on-premises network via the Hub's VPN Gateway.

4.  **Workloads:**
    * Two Windows Server 2025 VMs (`vm_dc` and `vm_app`) are deployed into the Spoke's application subnet with static private IPs. These are intended to be a Domain Controller and an Application Server, respectively. Technically do whatever with them :)

5.  **Secure Storage:**
    * A separate resource group (`rg-storage`) is created for a `azurerm_storage_account`.
    * **Public access is disabled** on the storage account.
    * A **Private Endpoint** (`azurerm_private_endpoint`) is created in the Spoke VNet, allowing your VMs to access the storage blob service securely over the Azure internal network.
    * A **Private DNS Zone** (`privatelink.blob.core.windows.net`) is created and linked to *both* VNets, ensuring correct DNS resolution for the private endpoint.

---

## How to Use This Template

Follow these steps to customize and deploy your infrastructure.

### 1. Prerequisites

* An active Azure Subscription.
* [Terraform](https://developer.hashicorp.com/terraform/downloads) (v1.0 or later) installed.
* Azure CLI

### 2. Configuration (What You MUST Edit)

This template is variable-driven. You **must** edit the `default` values in the `main.tf` file to match your environment *before* deploying.

#### Critical VPN & On-Premises Variables

These are required to build the Site-to-Site VPN tunnel to your office.

| Variable | `main.tf` Default | Description |
| :--- | :--- | :--- |
| `office_public_ip` | `"1.1.1.1"` | **Change this** to the public IP address of your office firewall. |
| `office_address_space` | `["192.168.1.0/24"]` | **Change this** to the internal IP range(s) of your office network. |
| `preshared_key` | `"YourSuperSecretKeyHere"` | **Change this** to a strong, complex pre-shared key (PSK). |

#### VM Credentials

| Variable | `main.tf` Default | Description |
| :--- | :--- | :--- |
| `admin_username` | `"azureadmin"` | (Optional) Change the local admin username for the VMs. |
| `admin_password` | `"Password1234!"` | **Change this** to a complex local admin password. |

#### Naming & Tagging

| Variable | `main.tf` Default | Description |
| :--- | :--- | :--- |
| `storage_account_name_prefix` | `"stdatacompanyx"` | **Change this**. Must be globally unique (all lowercase, no symbols). |
| `vm_dc_name` | `"xxx-vm-dc-001"` | Change the `xxx` prefix to your customer/project identifier. |
| `vm_app_name` | `"xxx-vm-app-001"` | Change the `xxx` prefix to your customer/project identifier. |
| `local.common_tags` | `Owner = "msp-name"` | **Edit the `locals` block** to set the `Owner` tag and other tags. |

#### Security Rule (In-Code Edit)

One security rule is **hard-coded** and must be changed directly in the `azurerm_network_security_group.nsg_prod` resource block (line 330):

> ```hcl
>   security_rule {
>     name                       = "Allow_RMM_Inbound"
>     ...
>     source_address_prefixes    = ["1.3.4.4", "4.3.2.1"] # <-- EDIT THIS
>     description                = "Allow inbound RMM Connections."
>   }
> ```
>
> **You must change** the `source_address_prefixes` from the placeholder IPs to the **public IPs of your management/RMM tool** to allow remote access.

### 3. Deployment Steps

Once you have saved your configuration changes, run the standard Terraform commands:

```bash
# 1. Initialize the Terraform providers
terraform init

# 2. Review the plan to see what will be created
terraform plan

# 3. Apply the configuration and build the infrastructure
terraform apply
```
Enter yes when prompted to approve the deployment.

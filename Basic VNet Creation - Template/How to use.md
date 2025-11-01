# Basic Azure VNet and Subnet Terraform Template

This is a foundational Terraform template to deploy a basic network structure in Microsoft Azure.

It's designed as a starting point for simple applications or as a base module, establishing a single resource group, virtual network, and secured subnet.

## Architecture Overview

This template deploys the following core infrastructure:

1.  **Resource Group:** A single resource group (`rg-prod-001`) to contain all network resources.
2.  **Virtual Network (VNet):** A single VNet (`vnet-prod-uksouth-001`) with a `/16` address space.
3.  **Subnet:** One application subnet (`snet-prod-uksouth-001`) with a `/24` address space, carved out of the VNet.
4.  **Network Security Group (NSG):** A single NSG (`nsg-prod-uksouth-001`) that is created **empty** (containing no custom rules, only Azure defaults).
5.  **Subnet-NSG Association:** The empty NSG is immediately associated with the application subnet, ensuring any resources placed in it are firewalled.
6.  **Tagging:** A `locals` block is used to define a set of common tags that are applied to all resources (except the subnet, which doesn't support tags at this level).

---

## How to Use This Template

Follow these steps to customize and deploy your infrastructure.

### 1. Prerequisites

* An active Azure Subscription.
* [Terraform](https://developer.hashicorp.com/terraform/downloads) (v1.0 or later) installed.
* Azure CLI installed and authenticated (`az login`).

### 2. Configuration (What You MUST Edit)

> **Important:** Unlike more complex templates, this file **uses hard-coded names** instead of variables. You must edit the `main.tf` file directly to change names, IP addresses, and other properties.

| Category | Resource Block | Property to Edit |
| :--- | :--- | :--- |
| **Tagging** | `locals { ... }` | Change the `Owner` and other tag values to match your standards. |
| **Resource Group** | `azurerm_resource_group.rg_prod` | `name` (e.g., "rg-prod-001"), `location` (e.g., "UK South") |
| **Virtual Network** | `azurerm_virtual_network.vnet_prod` | `name`, `address_space` (e.g., `["10.0.0.0/16"]`) |
| **Subnet** | `azurerm_subnet.snet_prod` | `name`, `address_prefixes` (e.g., `["10.0.1.0/24"]`) |
| **Network Security** | `azurerm_network_security_group.nsg_prod` | `name`. **You must add `security_rule` blocks here.** |

#### Add Security Rules

The deployed NSG (`nsg-prod`) is **empty**. You must add `security_rule` blocks to it to allow necessary traffic (like RDP, SSH, or web traffic).

**Example:** To add a rule allowing RDP from a specific IP, edit the `azurerm_network_security_group.nsg_prod` resource like this:

```hcl
resource "azurerm_network_security_group" "nsg_prod" {
  name                = "nsg-prod-uksouth-001"
  location            = azurerm_resource_group.rg_prod.location
  resource_group_name = azurerm_resource_group.rg_prod.name
  tags                = local.common_tags

  # --- ADD RULES LIKE THIS ---
  security_rule {
    name                       = "AllowRDP_From_AdminIP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "YOUR_OFFICE_IP_HERE" # <-- CHANGE THIS
    destination_address_prefix = "*"
    description                = "Allow RDP from office."
  }
}

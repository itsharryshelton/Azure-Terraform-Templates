#main.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# ===================================================================
# Edit this section - Naming Variables
# Define names for all major resources here for easy change.
# ===================================================================

#Resource Group Names
variable "rg_vpn_name" {
  type        = string
  description = "Name for the Hub/VPN Resource Group."
  default     = "rg-vpn-001"
}

variable "rg_prod_name" {
  type        = string
  description = "Name for the Spoke/Production Resource Group."
  default     = "rg-prod-001"
}

variable "rg_storage_name" {
  type        = string
  description = "Name for the Storage Resource Group."
  default     = "rg-storage-001"
}

#Network Names
variable "vnet_hub_name" {
  type        = string
  description = "Name for the Hub Virtual Network."
  default     = "vnet-vpn-uksouth-001"
}

variable "vnet_spoke_name" {
  type        = string
  description = "Name for the Spoke Virtual Network."
  default     = "vnet-prod-uksouth-001"
}

variable "snet_prod_name" {
  type        = string
  description = "Name for the production subnet in the Spoke VNet."
  default     = "snet-prod-uksouth-001"
}

variable "vng_name" {
  type        = string
  description = "Name for the Virtual Network Gateway."
  default     = "vgw-prod-uksouth-001"
}

variable "nat_gateway_name" {
  type        = string
  description = "Name for the NAT Gateway."
  default     = "nat-prod-uksouth-001"
}

variable "nsg_prod_name" {
  type        = string
  description = "Name for the production subnet Network Security Group."
  default     = "nsg-prod-uksouth-001"
}

variable "vpn_sku" {
  type        = string
  description = "Which SKU for the VPN Gateway"
  default     = "VpnGw1AZ"
}

#VPN Connection to Office Variables
variable "local_network_gateway_name" {
  type        = string
  description = "Name of the Local Network Gateway representing the office."
  default     = "lgw-office-001"
}

variable "vpn_connection_name" {
  type        = string
  description = "Name of the VPN connection resource."
  default     = "toHQ"
}

variable "office_public_ip" {
  type        = string
  description = "The public IP address of the office firewall for the VPN."
  default     = "1.1.1.1" #Replace with your actual office public IP
}

variable "office_address_space" {
  type        = list(string)
  description = "The internal IP address range(s) of the on-premises office network."
  default     = ["192.168.1.0/24"] #Replace with your actual office private IP range(s)
}

variable "preshared_key" {
  type        = string
  description = "The pre-shared key for the Site-to-Site VPN."
  sensitive   = true
  default     = "YourSuperSecretKeyHere"
}

#Virtual Machine Names
variable "vm_dc_name" {
  type        = string
  description = "Name for the VM 1."
  default     = "xxx-vm-dc-001" #xxx equals a customer reference
}

variable "vm_app_name" {
  type        = string
  description = "Name for the VM 2."
  default     = "xxx-vm-app-001" #xxx equals a customer reference
}

# Storage Account
variable "storage_account_name_prefix" {
  type        = string
  description = "Name for the globally unique storage account name."
  default     = "stdatacompanyx" #Make sure the name is globally unqiue
}

#Define variables for VM credentials for DC/App to begin with
variable "admin_username" {
  type        = string
  description = "Administrator username for the Windows VM."
  default     = "azureadmin"
}

variable "admin_password" {
  type        = string
  description = "Administrator password for the Windows VM. Must be complex."
  sensitive   = true
  default     = "Password1234!"
}

# ===================================================================
# Tag Definition
# ===================================================================

locals {
  common_tags = {
    DataClassification = "internal"
    Environment        = "prod"
    RevenueImpact      = "missioncritical"
    Owner              = "msp-name"
    Region             = "UK South"
  }
}

# ===================================================================
# HUB NETWORK RESOURCES
# Contains shared services like the VPN Gateway.
# ===================================================================

#1a. Create the Hub Resource Group
resource "azurerm_resource_group" "rg_vpn" {
  name     = var.rg_vpn_name
  location = "UK South"
  tags     = local.common_tags
}

#1b. Create the Hub Virtual Network
resource "azurerm_virtual_network" "vnet_hub" {
  name                = var.vnet_hub_name
  location            = azurerm_resource_group.rg_vpn.location
  resource_group_name = azurerm_resource_group.rg_vpn.name
  address_space       = ["10.1.0.0/16"]
  tags                = local.common_tags
}

#1c. Create the Gateway Subnet in the Hub VNet
resource "azurerm_subnet" "snet_vpn_gateway" {
  name                 = "GatewaySubnet" # This name is required by Azure - don't change
  resource_group_name  = azurerm_resource_group.rg_vpn.name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  address_prefixes     = ["10.1.255.0/27"]
}

#1d. Create a Public IP for the Virtual Network Gateway
resource "azurerm_public_ip" "pip_vng" {
  name                = "pip-${var.vng_name}"
  location            = azurerm_resource_group.rg_vpn.location
  resource_group_name = azurerm_resource_group.rg_vpn.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
  tags                = local.common_tags
}

#1e. Create the Virtual Network Gateway in the Hub
resource "azurerm_virtual_network_gateway" "vngw_prod" {
  name                = var.vng_name
  location            = azurerm_resource_group.rg_vpn.location
  resource_group_name = azurerm_resource_group.rg_vpn.name
  tags                = local.common_tags

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = var.vpn_sku

  ip_configuration {
    name                          = "vngw-ip-config"
    public_ip_address_id          = azurerm_public_ip.pip_vng.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.snet_vpn_gateway.id
  }

  depends_on = [azurerm_public_ip.pip_vng]
}

#1f. Create the Local Network Gateway (represents the on-premises office)
resource "azurerm_local_network_gateway" "lng_office" {
  name                = var.local_network_gateway_name
  location            = azurerm_resource_group.rg_vpn.location
  resource_group_name = azurerm_resource_group.rg_vpn.name
  gateway_address     = var.office_public_ip
  address_space       = var.office_address_space
  tags                = local.common_tags
}

#1g. Create the Site-to-Site VPN Connection
resource "azurerm_virtual_network_gateway_connection" "vpn_to_office" {
  name                = var.vpn_connection_name
  location            = azurerm_resource_group.rg_vpn.location
  resource_group_name = azurerm_resource_group.rg_vpn.name
  tags                = local.common_tags

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vngw_prod.id
  local_network_gateway_id   = azurerm_local_network_gateway.lng_office.id
  shared_key                 = var.preshared_key
}


# ===================================================================
# SPOKE NETWORK RESOURCES
# Contains application workloads like VMs.
# ===================================================================

#2a. Create the Spoke Resource Group
resource "azurerm_resource_group" "rg_prod" {
  name     = var.rg_prod_name
  location = "UK South"
  tags     = local.common_tags
}

#2b. Create the Spoke Virtual Network
resource "azurerm_virtual_network" "vnet_spoke" {
  name                = var.vnet_spoke_name
  location            = azurerm_resource_group.rg_prod.location
  resource_group_name = azurerm_resource_group.rg_prod.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
}

#2c. Create the application Subnet in the Spoke VNet
resource "azurerm_subnet" "snet_prod" {
  name                 = var.snet_prod_name
  resource_group_name  = azurerm_resource_group.rg_prod.name
  virtual_network_name = azurerm_virtual_network.vnet_spoke.name
  address_prefixes     = ["10.0.1.0/24"]
}

#2d. Create a Public IP for the NAT Gateway
resource "azurerm_public_ip" "pip_nat" {
  name                = "pip-${var.nat_gateway_name}"
  location            = azurerm_resource_group.rg_prod.location
  resource_group_name = azurerm_resource_group.rg_prod.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
  tags                = local.common_tags
}

#2e. Create the NAT Gateway for controlled internet egress
resource "azurerm_nat_gateway" "nat_gateway" {
  name                = var.nat_gateway_name
  location            = azurerm_resource_group.rg_prod.location
  resource_group_name = azurerm_resource_group.rg_prod.name
  sku_name            = "Standard"
  tags                = local.common_tags
}

#2f. Associate the Public IP with the NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "nat_ip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.nat_gateway.id
  public_ip_address_id = azurerm_public_ip.pip_nat.id
}

#2g. Associate the NAT Gateway with the application subnet
resource "azurerm_subnet_nat_gateway_association" "nat_assoc" {
  subnet_id      = azurerm_subnet.snet_prod.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway.id
}


# ===================================================================
# VNET PEERING
# Connects the Hub and Spoke networks.
# ===================================================================

#3a. Peer Spoke VNet to Hub VNet
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-spoke-to-hub"
  resource_group_name       = azurerm_resource_group.rg_prod.name
  virtual_network_name      = azurerm_virtual_network.vnet_spoke.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_hub.id
  allow_gateway_transit     = false
  use_remote_gateways       = true #Allows spoke to use the hub's VPN gateway
}

# 3b. Peer Hub VNet to Spoke VNet
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-spoke"
  resource_group_name       = azurerm_resource_group.rg_vpn.name
  virtual_network_name      = azurerm_virtual_network.vnet_hub.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_spoke.id
  allow_gateway_transit     = true #Allows hub to act as a gateway for the spoke
  use_remote_gateways       = false
}


# ===================================================================
# SPOKE WORKLOADS AND SECURITY
# ===================================================================

#4a. Create a Network Security Group for servers
resource "azurerm_network_security_group" "nsg_prod" {
  name                = var.nsg_prod_name
  location            = azurerm_resource_group.rg_prod.location
  resource_group_name = azurerm_resource_group.rg_prod.name
  tags                = local.common_tags

  #Inbound Security Rules
  security_rule {
    name                       = "AllowRDP_Inbound_From_VNet"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
    description                = "Allow RDP from within the VNet."
  }

  security_rule {
    name                       = "AllowAD_Inbound_From_VNet"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["53", "88", "135", "389", "445", "464", "636", "3268", "3269", "49152-65535"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
    description                = "Allow AD ports from within the VNet."
  }

  security_rule {
    name                       = "Allow_RMM_Inbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*" # TCP/UDP
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = ["1.3.4.4", "4.3.2.1"]
    destination_address_prefix = "*"
    description                = "Allow inbound RMM Connections."
  }
}

#4b. Associate the NSG with the application subnet
resource "azurerm_subnet_network_security_group_association" "snet_prod_nsg_assoc" {
  subnet_id                 = azurerm_subnet.snet_prod.id
  network_security_group_id = azurerm_network_security_group.nsg_prod.id
}

#4c. Create NIC for the VM 1
resource "azurerm_network_interface" "nic_dc" {
  name                = "${var.vm_dc_name}-nic"
  location            = azurerm_resource_group.rg_prod.location
  resource_group_name = azurerm_resource_group.rg_prod.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_prod.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
  }

  dns_servers = ["10.0.1.10"]
}

#4d. Associate the Prod NSG with the VM 1 NIC
resource "azurerm_network_interface_security_group_association" "nic_dc_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic_dc.id
  network_security_group_id = azurerm_network_security_group.nsg_prod.id
}

#4e. Create VM 1
resource "azurerm_windows_virtual_machine" "vm_dc" {
  name                  = var.vm_dc_name
  location              = azurerm_resource_group.rg_prod.location
  resource_group_name   = azurerm_resource_group.rg_prod.name
  size                  = "Standard_B2ms"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic_dc.id]
  patch_mode            = "AutomaticByPlatform"
  tags                  = local.common_tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }
}

#4f. Create NIC for the VM 2
resource "azurerm_network_interface" "nic_app" {
  name                = "${var.vm_app_name}-nic"
  location            = azurerm_resource_group.rg_prod.location
  resource_group_name = azurerm_resource_group.rg_prod.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_prod.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.11"
  }
}

#4g. Associate the Prod NSG with the VM 2 NIC
resource "azurerm_network_interface_security_group_association" "nic_app_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic_app.id
  network_security_group_id = azurerm_network_security_group.nsg_prod.id
}

#4h. Create the VM 2
resource "azurerm_windows_virtual_machine" "vm_app" {
  name                  = var.vm_app_name
  location              = azurerm_resource_group.rg_prod.location
  resource_group_name   = azurerm_resource_group.rg_prod.name
  size                  = "Standard_B2ms"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic_app.id]
  patch_mode            = "AutomaticByPlatform"
  tags                  = local.common_tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }
}


# ===================================================================
# STORAGE RESOURCES AND PRIVATE ENDPOINTS
# ===================================================================

#5a. Create the Storage Resource Group
resource "azurerm_resource_group" "rg_storage" {
  name     = var.rg_storage_name
  location = "UK South"
  tags     = local.common_tags
}

#5b. Create the Storage Account
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name_prefix
  location                 = azurerm_resource_group.rg_storage.location
  resource_group_name      = azurerm_resource_group.rg_storage.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  public_network_access_enabled = false
  tags                     = local.common_tags
}

#5c. Create a Private DNS Zone for the storage blob endpoint
resource "azurerm_private_dns_zone" "dns_zone_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg_vpn.name
}

#5d. Link the Private DNS Zone to the Hub VNet
resource "azurerm_private_dns_zone_virtual_network_link" "dns_link_hub" {
  name                  = "hub-dns-link"
  resource_group_name   = azurerm_resource_group.rg_vpn.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone_blob.name
  virtual_network_id    = azurerm_virtual_network.vnet_hub.id
}

#5e. Link the Private DNS Zone to the Spoke VNet
resource "azurerm_private_dns_zone_virtual_network_link" "dns_link_spoke" {
  name                  = "spoke-dns-link"
  resource_group_name   = azurerm_resource_group.rg_vpn.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone_blob.name
  virtual_network_id    = azurerm_virtual_network.vnet_spoke.id
}

#5f. Create the Private Endpoint for the Storage Account
resource "azurerm_private_endpoint" "storage_pe" {
  name                = "pe-storage-blob"
  location            = azurerm_resource_group.rg_prod.location
  resource_group_name = azurerm_resource_group.rg_prod.name
  subnet_id           = azurerm_subnet.snet_prod.id
  tags                = local.common_tags

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_zone_blob.id]
  }

  private_service_connection {
    name                           = "psc-storage-blob"
    private_connection_resource_id = azurerm_storage_account.storage.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
}

# main.tf
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

# Define variables for VM credentials and name
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

variable "vm_name" {
  type        = string
  description = "The name of the virtual machine."
  default     = "xx-vm-app-001"
}

variable "vm_size" {
  type        = string
  description = "What size VM"
  default     = "Standard_B2ms"
}


#Define common tags for all resources in a central location
locals {
  common_tags = {
    DataClassification = "internal"
    Environment        = "prod"
    RevenueImpact      = "missioncritical"
    Owner              = "msp-name"
    Region             = "UK South"
  }
}

#Create the Resource Group
#All resources will be deployed into this group in the UK South region.
resource "azurerm_resource_group" "rg_prod" {
  name     = "rg-prod-001"
  location = "UK South"
  tags     = local.common_tags
}

#Create the Virtual Network
resource "azurerm_virtual_network" "vnet_prod" {
  name                = "vnet-prod-uksouth-001"
  location            = azurerm_resource_group.rg_prod.location
  resource_group_name = azurerm_resource_group.rg_prod.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
}

#Create the production subnet
resource "azurerm_subnet" "snet_prod" {
  name                 = "snet-prod-uksouth-001"
  resource_group_name  = azurerm_resource_group.rg_prod.name
  virtual_network_name = azurerm_virtual_network.vnet_prod.name
  address_prefixes     = ["10.0.1.0/24"]
}

#Create a Network Security Group (NSG) for the production subnet
resource "azurerm_network_security_group" "nsg_prod" {
  name                = "nsg-prod-uksouth-001"
  location            = azurerm_resource_group.rg_prod.location
  resource_group_name = azurerm_resource_group.rg_prod.name
  tags                = local.common_tags

  #\\ Inbound Security Rules //
  security_rule {
    name                       = "DenyAnyRDPInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Block RDP from any Source."
  }

  security_rule {
    name                       = "AllowAnyHTTPSInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
    description                = "Allow inbound HTTPS Traffic to a web server."
  }

  security_rule {
    name                       = "Allow_RMM_Inbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = ["1.2.3.4", "4.3.2.1"]
    destination_address_prefix = "*"
    description                = "Allow inbound RMM Connections."
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Deny all other inbound traffic."
  }

  #\\ Outbound Security Rules //
  security_rule {
    name                        = "Allow_Internet_Outbound"
    priority                    = 100
    direction                   = "Outbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_ranges     = ["80", "443"]
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    description                 = "Allow Outbound Web Traffic."
  }

  security_rule {
    name                         = "Allow_RMM_Oubound"
    priority                     = 210
    direction                    = "Outbound"
    access                       = "Allow"
    protocol                     = "*"
    source_port_range            = "*"
    destination_port_range       = "*"
    source_address_prefix        = "*"
    destination_address_prefixes = ["1.2.3.4", "1.2.3.4"]
    description                  = "Allow RMM outbound."
  }

  security_rule {
    name                       = "DenyAllOutbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Deny all other outbound traffic."
  }
}

#Associate the NSG with the production subnet
resource "azurerm_subnet_network_security_group_association" "snet_prod_nsg_assoc" {
  subnet_id                 = azurerm_subnet.snet_prod.id
  network_security_group_id = azurerm_network_security_group.nsg_prod.id
}

#Create NIC for the VM
resource "azurerm_network_interface" "nic_dc" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.rg_prod.location
  resource_group_name = azurerm_resource_group.rg_prod.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_prod.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10" #Change for if you don't like this IP :)
  }
}

#Create VM
resource "azurerm_windows_virtual_machine" "vm_dc" {
  name                  = var.vm_name
  location              = azurerm_resource_group.rg_prod.location
  resource_group_name   = azurerm_resource_group.rg_prod.name
  size                  = var.vm_size
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

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

#Define common tags for all resources in a central location
locals {
  common_tags = {
    DataClassification = "internal"
    Environment        = "prod"
    RevenueImpact      = "missioncritical"
    Owner              = "msp-name"
    Region             = "uksouth"
  }
}

#Create the Resource Group
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

#Create the primary application Subnet
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
}

#Associate the NSG with the production subnet
#This applies the rules defined in the NSG to all resources within snet-prod-uksouth-001.
resource "azurerm_subnet_network_security_group_association" "snet_prod_nsg_assoc" {
  subnet_id                 = azurerm_subnet.snet_prod.id
  network_security_group_id = azurerm_network_security_group.nsg_prod.id
}

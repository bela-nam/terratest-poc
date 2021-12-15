# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.0"
    }
    # template = {
    #   source = "hashicorp/template"
    #   version = "~> 2.0"
    # }
  }
}

provider "azurerm" {
  features {}
}

# this provider is not available for ARM macOS arch
# provider "template" {}

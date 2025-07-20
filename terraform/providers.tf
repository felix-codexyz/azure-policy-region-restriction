terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "remote" {
    organization = "felfun-spz-technologies-azure-platform"

    workspaces {
      name = "azure-policy-enforcer"
    }
  }
}

provider "azurerm" {
  features {}
}

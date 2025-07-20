terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  cloud {
    organization = "felfun-spz-technologies-azure-platform"

    workspaces {
      name = "azure-policy-region-restriction"
    }
  }
}

provider "azurerm" {
  features {}
}
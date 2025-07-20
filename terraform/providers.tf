terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  terraform { 
  cloud { 
    
    organization = "felfun-spz-technologies-azure-platform" 

    workspaces { 
      name = "azure-policy-region-restriction" 
    } 
  } 
}
 
 
}

provider "azurerm" {
  features {}
}

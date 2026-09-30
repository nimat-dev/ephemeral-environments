terraform {
  required_version = ">= 1.12.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.7"
    }
  }

  # State lives in Azure Storage (Entra auth, blob lease lock) and is encrypted client-side with the
  # Key Vault RSA key from bootstrap/a0-tofu-state.sh (DEC-038). enforced: never write plaintext state.
  backend "azurerm" {
    resource_group_name  = "nimatresourceg"
    storage_account_name = "nimattofustate"
    container_name       = "tfstate"
    key                  = "envs/nimat/team-cluster.tfstate"
    use_azuread_auth     = true
  }

  encryption {
    key_provider "azure_vault" "state" {
      vault_uri      = "https://nimat-tofu-kv.vault.azure.net"
      vault_key_name = "tofu-state"
      key_length     = 32
    }
    method "aes_gcm" "state" {
      keys = key_provider.azure_vault.state
    }
    state {
      method   = method.aes_gcm.state
      enforced = true
    }
    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "1325f79b-c2c1-437c-a8c7-a0746ab748d4"
}

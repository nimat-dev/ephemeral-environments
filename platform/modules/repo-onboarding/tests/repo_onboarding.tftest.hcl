# Offline contract of repo-onboarding (mock providers, plan only).
mock_provider "azurerm" {}
mock_provider "github" {}
mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "00000000-0000-0000-0000-00000000000a"
      tenant_id = "00000000-0000-0000-0000-00000000000b"
    }
  }
  mock_resource "azuread_application" {
    defaults = {
      id        = "/applications/00000000-0000-0000-0000-00000000000c"
      client_id = "00000000-0000-0000-0000-00000000000d"
    }
  }
  mock_resource "azuread_service_principal" {
    defaults = { object_id = "00000000-0000-0000-0000-00000000000e" }
  }
}

variables {
  repository     = "acme/shop"
  app            = "shop"
  image_name     = "shop"
  preview_domain = "shop.preview.example.org"
  federated_subjects = {
    gh-preview-env = "repo:acme/shop:environment:preview"
  }
  subscription_id = "00000000-0000-0000-0000-000000000001"
  cluster = {
    id                  = "/subscriptions/s/resourceGroups/rg/providers/Microsoft.ContainerService/managedClusters/aks"
    name                = "aks"
    resource_group_name = "rg"
    acr_id              = "/subscriptions/s/resourceGroups/rg/providers/Microsoft.ContainerRegistry/registries/acr"
    acr_name            = "acr"
    acr_login_server    = "acr.azurecr.io"
  }
}

run "identity_roles_and_github_vars" {
  command = plan

  assert {
    condition     = azuread_application.this.display_name == "gh-preview-shop"
    error_message = "Default app name gh-preview-<app>."
  }
  assert {
    condition     = azuread_application_federated_identity_credential.github["gh-preview-env"].issuer == "https://token.actions.githubusercontent.com"
    error_message = "GitHub OIDC issuer."
  }
  assert {
    condition     = toset(keys(azurerm_role_assignment.acr)) == toset(["AcrPush", "AcrDelete"])
    error_message = "Push + purge own images only."
  }
  assert {
    condition     = azurerm_role_assignment.aks_user.role_definition_name == "Azure Kubernetes Service Cluster User Role" && strcontains(azurerm_role_assignment.aks_user.scope, "/resourcegroups/")
    error_message = "Cluster user role on the cluster (lowercase scope as ARM stores it)."
  }
  assert {
    condition = (
      github_actions_environment_variable.this["PREVIEW_APP"].value == "shop" &&
      github_actions_environment_variable.this["PREVIEW_DOMAIN"].value == "shop.preview.example.org" &&
      github_actions_environment_variable.this["APP_IMAGE_NAME"].value == "shop" &&
      length(github_actions_environment_variable.this) == 13
    )
    error_message = "All 13 workflow variables, per repo."
  }
  assert {
    condition     = github_repository_environment.preview.repository == "shop" && github_repository_environment.preview.environment == "preview"
    error_message = "GitHub environment preview on the repo."
  }
}

run "guard_confines_to_app_prefix" {
  command = plan
  assert {
    condition     = strcontains(output.guard_manifest, "startsWith('preview-shop-')") && strcontains(output.guard_manifest, "name: preview-deployer-guard-shop")
    error_message = "Guard confines the SP to preview-<app>-*."
  }
  assert {
    condition     = !strcontains(output.guard_manifest, "secrets")
    error_message = "Guard grants nothing itself (no secrets)."
  }
}

run "rejects_bad_inputs" {
  command = plan
  variables {
    repository         = "not-a-repo"
    app                = "Shop_App"
    federated_subjects = { x = "repo:acme/shop:ref:refs/heads/main" }
  }
  expect_failures = [var.repository, var.app, var.federated_subjects]
}

# Offline contract of the team-cluster module (mock provider, plan only): the security/identity
# settings previews depend on (DEC-024/030/036/041) can't silently drift.
mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = { location = "eastus" }
  }
  mock_data "azurerm_client_config" {
    defaults = { tenant_id = "00000000-0000-0000-0000-000000000001" }
  }
  mock_resource "azurerm_dns_zone" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-team/providers/Microsoft.Network/dnsZones/team.example.org" }
  }
  mock_resource "azurerm_container_registry" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-team/providers/Microsoft.ContainerRegistry/registries/teamacr01" }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-team/providers/Microsoft.ManagedIdentity/userAssignedIdentities/cert-manager-dns"
      principal_id = "00000000-0000-0000-0000-000000000002"
    }
  }
  mock_resource "azurerm_kubernetes_cluster" {
    defaults = {
      id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-team/providers/Microsoft.ContainerService/managedClusters/aks-team"
      oidc_issuer_url = "https://oidc.example/"
    }
  }
}

# Mocks can't fill the computed kubelet_identity block, so plans target everything but the kubelet
# AcrPull assignment (its role is asserted from config text by tests/platform.bats).
variables {
  resource_group_name = "rg-team"
  cluster_name        = "aks-team"
  dns_prefix          = "aks-team"
  acr_name            = "teamacr01"
  dns_zone            = "team.example.org"
}

run "cluster_identity_and_auth" {
  command = plan
  plan_options {
    target = [
      azurerm_kubernetes_cluster.this,
      azurerm_container_registry.this,
      azurerm_dns_zone.this,
      azurerm_user_assigned_identity.cert_manager,
      azurerm_federated_identity_credential.cert_manager,
      azurerm_role_assignment.cert_manager_dns,
    ]
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.oidc_issuer_enabled && azurerm_kubernetes_cluster.this.workload_identity_enabled
    error_message = "OIDC issuer + workload identity must be on (GitHub OIDC, cert-manager DNS-01)."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.azure_active_directory_role_based_access_control[0].azure_rbac_enabled
    error_message = "Entra + Azure RBAC must be on (kubelogin for CI)."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].node_count == 1 && azurerm_kubernetes_cluster.this.sku_tier == "Free"
    error_message = "Test cluster: 1 node, Free tier (DEC-041)."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.node_provisioning_profile[0].mode == "Manual"
    error_message = "Node auto-provisioning stays off."
  }
  assert {
    condition     = length(azurerm_kubernetes_cluster.this.linux_profile) == 0
    error_message = "No SSH profile unless a key is given."
  }
}

run "registry_and_dns" {
  command = plan
  plan_options {
    target = [
      azurerm_kubernetes_cluster.this,
      azurerm_container_registry.this,
      azurerm_dns_zone.this,
      azurerm_user_assigned_identity.cert_manager,
      azurerm_federated_identity_credential.cert_manager,
      azurerm_role_assignment.cert_manager_dns,
    ]
  }

  assert {
    condition     = azurerm_container_registry.this.sku == "Basic" && !azurerm_container_registry.this.admin_enabled
    error_message = "ACR: Basic, no admin user (Entra only)."
  }
  assert {
    condition     = azurerm_federated_identity_credential.cert_manager.subject == "system:serviceaccount:cert-manager:cert-manager"
    error_message = "cert-manager federation subject."
  }
  assert {
    condition     = azurerm_role_assignment.cert_manager_dns.role_definition_name == "DNS Zone Contributor"
    error_message = "cert-manager may write DNS-01 TXT records."
  }
}

run "ssh_key_optional" {
  command = plan
  plan_options {
    target = [
      azurerm_kubernetes_cluster.this,
      azurerm_container_registry.this,
      azurerm_dns_zone.this,
      azurerm_user_assigned_identity.cert_manager,
      azurerm_federated_identity_credential.cert_manager,
      azurerm_role_assignment.cert_manager_dns,
    ]
  }
  variables {
    admin_ssh_public_key = "ssh-rsa AAAAtest"
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.linux_profile[0].admin_username == "azureuser"
    error_message = "SSH key renders a linux_profile."
  }
}

run "rejects_bad_inputs" {
  command = plan
  plan_options {
    target = [
      azurerm_kubernetes_cluster.this,
      azurerm_container_registry.this,
      azurerm_dns_zone.this,
      azurerm_user_assigned_identity.cert_manager,
      azurerm_federated_identity_credential.cert_manager,
      azurerm_role_assignment.cert_manager_dns,
    ]
  }
  variables {
    acr_name   = "Bad-Name"
    node_count = 0
  }
  expect_failures = [var.acr_name, var.node_count]
}

run "flux_off_by_default" {
  command = plan
  plan_options {
    target = [azurerm_kubernetes_cluster.this]
  }
  assert {
    condition     = length(azurerm_kubernetes_cluster_extension.flux) == 0 && length(azurerm_kubernetes_flux_configuration.platform) == 0
    error_message = "No Flux unless var.flux is set."
  }
}

run "flux_releases_then_config" {
  command = plan
  variables {
    flux = {
      repository_url = "https://github.com/example/platform"
      branch         = "main"
      path           = "./clusters/team"
    }
  }
  plan_options {
    target = [azurerm_kubernetes_cluster_extension.flux, azurerm_kubernetes_flux_configuration.platform]
  }
  assert {
    condition     = azurerm_kubernetes_cluster_extension.flux[0].configuration_settings["notification-controller.enabled"] == "false"
    error_message = "Notification controller off (CPU budget, DEC-049)."
  }
  assert {
    condition = (
      { for k in azurerm_kubernetes_flux_configuration.platform[0].kustomizations : k.name => k.path } == {
        releases = "./clusters/team/releases", config = "./clusters/team/config"
      } &&
      tolist([for k in azurerm_kubernetes_flux_configuration.platform[0].kustomizations : k.depends_on if k.name == "config"][0]) == tolist(["releases"])
    )
    error_message = "config kustomization depends on releases (CRDs first)."
  }
}

run "flux_rejects_bad_source" {
  command = plan
  variables {
    flux = {
      repository_url = "git@github.com:example/platform.git"
      branch         = "main"
      path           = "clusters/team"
    }
  }
  plan_options {
    target = [azurerm_kubernetes_flux_configuration.platform]
  }
  expect_failures = [var.flux]
}

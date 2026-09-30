# One team's preview platform (DEC-036): AKS with OIDC + workload identity + Entra/Azure RBAC, ACR the
# kubelet pulls from, the team's base DNS zone, and the cert-manager DNS-01 identity. In-cluster add-ons
# are Flux's job (F019); per-repo identities + extra domains are onboarding's (F020).

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"
  support_plan        = "KubernetesOfficial"

  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  # Break-glass admin kubeconfig stays available (DEC-024); CI uses Entra (kubelogin).
  local_account_disabled  = false
  node_os_upgrade_channel = "NodeImage"

  default_node_pool {
    name                 = "nodepool1"
    vm_size              = var.node_size
    node_count           = var.node_count
    os_disk_size_gb      = 128
    max_pods             = 250
    orchestrator_version = var.kubernetes_version
    upgrade_settings {
      max_surge = "10%"
    }
  }

  # Node auto-provisioning (Karpenter) off: one fixed system pool.
  node_provisioning_profile {
    mode = "Manual"
  }

  dynamic "linux_profile" {
    for_each = var.admin_ssh_public_key == null ? [] : [var.admin_ssh_public_key]
    content {
      admin_username = "azureuser"
      ssh_key {
        key_data = linux_profile.value
      }
    }
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "azure"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
  }

  tags = var.tags

  lifecycle {
    # Irrelevant in Manual mode; az leaves it empty, the provider would push "Auto" on every plan.
    ignore_changes = [node_provisioning_profile[0].default_node_pools]
  }
}

resource "azurerm_container_registry" "this" {
  name                = var.acr_name
  resource_group_name = data.azurerm_resource_group.this.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

resource "azurerm_dns_zone" "this" {
  name                = var.dns_zone
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = var.tags
}

# cert-manager solves DNS-01 as this identity (workload identity on its service account, a3).
resource "azurerm_user_assigned_identity" "cert_manager" {
  name                = "cert-manager-dns"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "cert_manager" {
  name                      = "cert-manager"
  user_assigned_identity_id = azurerm_user_assigned_identity.cert_manager.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject                   = "system:serviceaccount:cert-manager:cert-manager"
}

resource "azurerm_role_assignment" "cert_manager_dns" {
  # Azure stores role-assignment scopes with ARM's lowercase `dnszones` segment (as a3 created it); the
  # zone id says `dnsZones`, and a scope diff forces replacement.
  scope                = replace(azurerm_dns_zone.this.id, "dnsZones", "dnszones")
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.cert_manager.principal_id
}

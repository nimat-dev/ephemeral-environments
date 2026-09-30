# Adopt the resources bash provisioning created (F018, DEC-042): plan must show imports only, no changes.
import {
  to = module.team_cluster.azurerm_kubernetes_cluster.this
  id = "/subscriptions/1325f79b-c2c1-437c-a8c7-a0746ab748d4/resourceGroups/nimatresourceg/providers/Microsoft.ContainerService/managedClusters/aks-preview"
}

import {
  to = module.team_cluster.azurerm_container_registry.this
  id = "/subscriptions/1325f79b-c2c1-437c-a8c7-a0746ab748d4/resourceGroups/nimatresourceg/providers/Microsoft.ContainerRegistry/registries/nimatpreviewacr"
}

import {
  to = module.team_cluster.azurerm_role_assignment.kubelet_acr_pull
  id = "/subscriptions/1325f79b-c2c1-437c-a8c7-a0746ab748d4/resourceGroups/nimatresourceg/providers/Microsoft.ContainerRegistry/registries/nimatpreviewacr/providers/Microsoft.Authorization/roleAssignments/13ffc934-2506-4a0a-840c-0e1f0daa3b7f"
}

import {
  to = module.team_cluster.azurerm_dns_zone.this
  id = "/subscriptions/1325f79b-c2c1-437c-a8c7-a0746ab748d4/resourceGroups/nimatresourceg/providers/Microsoft.Network/dnsZones/preview.nimat.dev"
}

import {
  to = module.team_cluster.azurerm_user_assigned_identity.cert_manager
  id = "/subscriptions/1325f79b-c2c1-437c-a8c7-a0746ab748d4/resourceGroups/nimatresourceg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/cert-manager-dns"
}

import {
  to = module.team_cluster.azurerm_federated_identity_credential.cert_manager
  id = "/subscriptions/1325f79b-c2c1-437c-a8c7-a0746ab748d4/resourceGroups/nimatresourceg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/cert-manager-dns/federatedIdentityCredentials/cert-manager"
}

import {
  to = module.team_cluster.azurerm_role_assignment.cert_manager_dns
  id = "/subscriptions/1325f79b-c2c1-437c-a8c7-a0746ab748d4/resourceGroups/nimatresourceg/providers/Microsoft.Network/dnszones/preview.nimat.dev/providers/Microsoft.Authorization/roleAssignments/5274b9f7-e94c-41e0-8f67-65b512f8bb54"
}

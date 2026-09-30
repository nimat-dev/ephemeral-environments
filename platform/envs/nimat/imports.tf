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

# --- F020: repo onboarding adopts what a5/a6 created for this repo ---
import {
  to = module.repo["todo"].azuread_application.this
  id = "/applications/30b3ab4d-f31b-4ad9-aee8-68a9adb7fc9b"
}

import {
  to = module.repo["todo"].azuread_service_principal.this
  id = "/servicePrincipals/b34bba52-17f6-4b85-9b1b-9724ae59236c"
}

import {
  to = module.repo["todo"].azuread_application_federated_identity_credential.github["gh-preview-env"]
  id = "30b3ab4d-f31b-4ad9-aee8-68a9adb7fc9b/federatedIdentityCredential/34675290-c1a4-4784-9c89-3dc5b98baa20"
}

import {
  to = module.repo["todo"].azuread_application_federated_identity_credential.github["gh-preview-env-immutable"]
  id = "30b3ab4d-f31b-4ad9-aee8-68a9adb7fc9b/federatedIdentityCredential/c5389c89-07b9-4c6a-8b79-86dd326022a5"
}

import {
  to = module.repo["todo"].azurerm_role_assignment.acr["AcrPush"]
  id = "/subscriptions/1325f79b-c2c1-437c-a8c7-a0746ab748d4/resourceGroups/nimatresourceg/providers/Microsoft.ContainerRegistry/registries/nimatpreviewacr/providers/Microsoft.Authorization/roleAssignments/85955f18-cf1f-45da-adf9-aa7f62b1e0d7"
}

import {
  to = module.repo["todo"].azurerm_role_assignment.acr["AcrDelete"]
  id = "/subscriptions/1325f79b-c2c1-437c-a8c7-a0746ab748d4/resourceGroups/nimatresourceg/providers/Microsoft.ContainerRegistry/registries/nimatpreviewacr/providers/Microsoft.Authorization/roleAssignments/6a35e32a-6fb8-4e15-b12b-bc60b69568b9"
}

import {
  to = module.repo["todo"].azurerm_role_assignment.aks_user
  id = "/subscriptions/1325f79b-c2c1-437c-a8c7-a0746ab748d4/resourcegroups/nimatresourceg/providers/Microsoft.ContainerService/managedClusters/aks-preview/providers/Microsoft.Authorization/roleAssignments/a3d18112-736c-4368-b0c5-b452e2af7ca5"
}

import {
  to = module.repo["todo"].github_repository_environment.preview
  id = "ephemeral-environments:preview"
}

import {
  for_each = toset(["AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID", "ACR_NAME", "ACR_LOGIN_SERVER", "APP_IMAGE_NAME", "AKS_CLUSTER", "AKS_RESOURCE_GROUP", "PREVIEW_DOMAIN", "PREVIEW_APP", "INTERCEPTOR_FQDN", "INTERCEPTOR_PORT", "INGRESS_CLASS"])
  to       = module.repo["todo"].github_actions_environment_variable.this[each.key]
  id       = "ephemeral-environments:preview:${each.key}"
}

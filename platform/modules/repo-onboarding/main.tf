# One repo's access to its team's preview cluster (F020): an Entra app/SP GitHub Actions signs in as
# (OIDC, no secrets), its Azure roles, the GitHub `preview` environment + variables the workflows read,
# and the Kubernetes guard (rendered for Flux) that confines it to preview-<app>-* namespaces.
# Replaces bootstrap/a5 + a6 (DEC-050).

data "azuread_client_config" "current" {}

resource "azuread_application" "this" {
  display_name = coalesce(var.display_name, "gh-preview-${var.app}")
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "this" {
  client_id = azuread_application.this.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "github" {
  # checkov:skip=CKV_AZURE_249:subjects are validated to be environment-scoped (var validation); the immutable form repo:<owner>@<id>/<repo>@<id>:… is stricter than the pattern Checkov recognises
  for_each       = var.federated_subjects
  application_id = azuread_application.this.id
  display_name   = each.key
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = each.value
}

# Push + purge its own images (DEC-034/046); kubelogin sign-in to the cluster (k8s RBAC below does the rest).
resource "azurerm_role_assignment" "acr" {
  for_each             = toset(["AcrPush", "AcrDelete"])
  scope                = var.cluster.acr_id
  role_definition_name = each.key
  principal_id         = azuread_service_principal.this.object_id
}

resource "azurerm_role_assignment" "aks_user" {
  # ARM stores this scope with a lowercase `resourcegroups` segment (as a5 created it); a casing diff
  # would force a replacement.
  scope                = replace(var.cluster.id, "resourceGroups", "resourcegroups")
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_service_principal.this.object_id
}

locals {
  repo_name = split("/", var.repository)[1]
  variables = {
    AZURE_CLIENT_ID       = azuread_application.this.client_id
    AZURE_TENANT_ID       = data.azuread_client_config.current.tenant_id
    AZURE_SUBSCRIPTION_ID = var.subscription_id
    ACR_NAME              = var.cluster.acr_name
    ACR_LOGIN_SERVER      = var.cluster.acr_login_server
    APP_IMAGE_NAME        = var.image_name
    AKS_CLUSTER           = var.cluster.name
    AKS_RESOURCE_GROUP    = var.cluster.resource_group_name
    PREVIEW_DOMAIN        = var.preview_domain
    PREVIEW_APP           = var.app
    INTERCEPTOR_FQDN      = var.interceptor.fqdn
    INTERCEPTOR_PORT      = tostring(var.interceptor.port)
    INGRESS_CLASS         = var.ingress_class
  }
}

resource "github_repository_environment" "preview" {
  repository  = local.repo_name
  environment = "preview"
}

resource "github_actions_environment_variable" "this" {
  for_each      = local.variables
  repository    = local.repo_name
  environment   = github_repository_environment.preview.environment
  variable_name = each.key
  value         = each.value
}

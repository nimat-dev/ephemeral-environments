output "cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "acr_login_server" {
  value = azurerm_container_registry.this.login_server
}

output "acr_id" {
  value = azurerm_container_registry.this.id
}

output "dns_zone_id" {
  value = azurerm_dns_zone.this.id
}

output "dns_zone_name_servers" {
  value = azurerm_dns_zone.this.name_servers
}

output "cert_manager_client_id" {
  value = azurerm_user_assigned_identity.cert_manager.client_id
}

output "cert_manager_principal_id" {
  value = azurerm_user_assigned_identity.cert_manager.principal_id
}

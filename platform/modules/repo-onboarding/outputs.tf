output "client_id" {
  value = azuread_application.this.client_id
}

output "principal_object_id" {
  value = azuread_service_principal.this.object_id
}

output "guard_manifest" {
  description = "Kubernetes RBAC + admission guard for this repo, written into clusters/<team>/config/repos/ for Flux."
  value = templatefile("${path.module}/guard.yaml.tftpl", {
    app        = var.app
    repository = var.repository
    principal  = azuread_service_principal.this.object_id
  })
}

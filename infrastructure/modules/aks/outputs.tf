output "cluster_id" {
  description = "AKS Cluster ID"
  value       = var.enable_aks_deployment ? azurerm_kubernetes_cluster.aks[0].id : null
}

output "cluster_name" {
  description = "AKS Cluster name"
  value       = var.enable_aks_deployment ? azurerm_kubernetes_cluster.aks[0].name : null
}

output "cluster_fqdn" {
  description = "AKS Cluster FQDN"
  value       = var.enable_aks_deployment ? azurerm_kubernetes_cluster.aks[0].fqdn : null
}

output "kube_config" {
  description = "AKS Cluster kube config"
  value       = var.enable_aks_deployment ? azurerm_kubernetes_cluster.aks[0].kube_config_raw : null
  sensitive   = true
}

output "kubelet_identity_object_id" {
  description = "Kubelet identity object ID"
  value       = var.enable_aks_deployment ? azurerm_kubernetes_cluster.aks[0].kubelet_identity[0].object_id : null
}

output "cluster_identity_principal_id" {
  description = "AKS cluster identity principal ID"
  value       = var.enable_aks_deployment ? azurerm_kubernetes_cluster.aks[0].identity[0].principal_id : null
}

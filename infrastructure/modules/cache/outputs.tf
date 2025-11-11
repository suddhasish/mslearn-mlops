output "redis_cache_id" {
  description = "Redis Cache resource ID"
  value       = var.enable_redis_cache ? azurerm_redis_cache.mlops[0].id : null
}

output "redis_cache_name" {
  description = "Redis Cache name"
  value       = var.enable_redis_cache ? azurerm_redis_cache.mlops[0].name : null
}

output "redis_cache_hostname" {
  description = "Redis Cache hostname"
  value       = var.enable_redis_cache ? azurerm_redis_cache.mlops[0].hostname : null
}

output "redis_cache_ssl_port" {
  description = "Redis Cache SSL port"
  value       = var.enable_redis_cache ? azurerm_redis_cache.mlops[0].ssl_port : null
}

output "redis_cache_primary_access_key" {
  description = "Redis Cache primary access key"
  value       = var.enable_redis_cache ? azurerm_redis_cache.mlops[0].primary_access_key : null
  sensitive   = true
}

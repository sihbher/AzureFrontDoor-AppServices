

output "fron_door_endpoint" {
  value = azurerm_cdn_frontdoor_endpoint.my_endpoint.host_name
}

output "app_service1_url" {
  value = module.app_service1.resource_uri
}
output "app_service2_url" {
  value = module.app_service2.resource_uri
}
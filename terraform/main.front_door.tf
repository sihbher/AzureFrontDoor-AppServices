
resource "azurerm_cdn_frontdoor_profile" "my_front_door" {
  name                = module.naming.frontdoor.name_unique
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = var.front_door_sku_name
}

resource "azurerm_cdn_frontdoor_endpoint" "my_endpoint" {
  name                     = module.naming.cdn_endpoint.name_unique
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
}

resource "azurerm_cdn_frontdoor_origin_group" "webapps_origin" {
  name                     = "webapps-origin"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
  session_affinity_enabled = false

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/"
    request_type        = "GET"
    protocol            = "Http"
    interval_in_seconds = 60
  }
}

#Origin app 1
resource "azurerm_cdn_frontdoor_origin" "origin_app1" {
  name                          = "primary-app"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.webapps_origin.id

  enabled                        = true
  host_name                      = module.app_service1.resource.default_hostname
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = module.app_service1.resource.default_hostname
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

#Origin app 2
resource "azurerm_cdn_frontdoor_origin" "origin_app2" {
  name                          = "secondary-app"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.webapps_origin.id

  enabled                        = true
  host_name                      = module.app_service2.resource.default_hostname
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = module.app_service2.resource.default_hostname
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "res-3" {
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.my_endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.webapps_origin.id
  name                          = "route"
  patterns_to_match             = ["/*"]
  supported_protocols           = ["Http", "Https"]

  cdn_frontdoor_origin_ids = [azurerm_cdn_frontdoor_origin.origin_app1.id, azurerm_cdn_frontdoor_origin.origin_app2.id]

}

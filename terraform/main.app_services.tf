resource "azurerm_service_plan" "servicePlan1" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.app_service_plan.name_unique}-${var.primary_location}"
  os_type             = "Linux"
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "B1"
}

resource "azurerm_service_plan" "servicePlan2" {
  location            = var.secondary_location
  name                = "${module.naming.app_service_plan.name_unique}-${var.secondary_location}"
  os_type             = "Linux"
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "B1"
}

module "app_service1" {
  source  = "Azure/avm-res-web-site/azurerm"
  version = "0.9.1"

  name                = "${module.naming.app_service.name_unique}-${var.primary_location}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  kind                        = "webapp"
  os_type                     = var.os_type
  service_plan_resource_id    = azurerm_service_plan.servicePlan1.id
  enable_application_insights = false
  site_config = {
    application_stack = {
      node = {
        current_stack = "node"
        node_version  = "18-lts"
      }
    }

    # ip_restriction = {
    #   azfd = {
    #     headers = {
    #       fd1 = {
    #         x_azure_fdid = [azurerm_cdn_frontdoor_profile.my_front_door.resource_guid]
    #       }
    #     }
    #     priority    = 100
    #     service_tag = "AzureFrontDoor.Backend"
    #     action      = "Allow"
    #   }
    # }


  }

}

module "app_service2" {
  source  = "Azure/avm-res-web-site/azurerm"
  version = "0.9.1"

  name                = "${module.naming.app_service.name_unique}-${var.secondary_location}"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.secondary_location

  kind                        = "webapp"
  os_type                     = var.os_type
  service_plan_resource_id    = azurerm_service_plan.servicePlan2.id
  enable_application_insights = false
  site_config = {
    application_stack = {
      node = {
        current_stack = "node"
        node_version  = "18-lts"
      }
    }
    # ip_restriction = {
    #   azfd = {
    #     headers = {
    #       x_azure_fdid = [azurerm_cdn_frontdoor_profile.my_front_door.resource_guid]
    #     }
    #     priority    = 100
    #     service_tag = "AzureFrontDoor.Backend"
    #     action      = "Allow"
    #   }
    # }
  }
}

resource "azurerm_cdn_frontdoor_firewall_policy" "firewall_policy" {
  mode                = "Prevention"
  name                = "WAFPolicyWebApps"
  redirect_url        = "https://docs.microsoft.com/en-us/azure/web-application-firewall"
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = var.front_door_sku_name
  custom_rule {
    action               = "Block"
    name                 = "RateLimitRule1"
    rate_limit_threshold = 5
    type                 = "RateLimitRule"
    match_condition {
      match_values   = ["promo"]
      match_variable = "QueryString"
      operator       = "Contains"
    }
  }
  managed_rule {
    action  = "Block"
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    override {
      rule_group_name = "SQLI"
      rule {
        action  = "AnomalyScoring"
        enabled = true
        rule_id = "942230"
        exclusion {
          match_variable = "RequestHeaderNames"
          operator       = "StartsWith"
          selector       = "user"
        }
      }
    }
  }
  managed_rule {
    action  = "Block"
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.1"
  }
}


resource "azurerm_cdn_frontdoor_security_policy" "frontdoor_security_policy" {
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
  name                     = "my-security-policy"
  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.firewall_policy.id
      association {
        patterns_to_match = ["/*"]
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.my_endpoint.id
        }
      }
    }
  }
}
#Tutorial: Create a multi-region app - Azure App Service | Microsoft Learn
#https://learn.microsoft.com/en-us/azure/app-service/tutorial-multi-region-app

#variables
region1="eastus2"
region2="westus"
random_string=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 4)
rg_name="AZFD-MultiRegionApp-$random_string-RG"
fd_profile_name="my-enterprise-azfd-$random_string"
fd_orig_group_name="my-eshop-origin-group"
app1_name=myeshop-$random_string-$region1
app2_name=myeshop-$random_string-$region2
endpoint_name=my-eshop-endpoint-$random_string
echo "Random string: $random_string"
tags=("delete=yes" "createdBy=Azure CLI (Bash)", "hidden-title=WAF and Azure Front Door PoC")

#Login to Azure
#az login

az group create --name $rg_name --location $region1 --tags $tags #'delete'='yes'

az appservice plan create --name "appserviceplaneastus2" --resource-group $rg_name --is-linux --location $region1 --tags $tags
az appservice plan create --name "appserviceplanwestus" --resource-group $rg_name --is-linux --location $region2 --tags $tags

az webapp create --name $app1_name --resource-group $rg_name --plan appserviceplaneastus2 --runtime NODE:18-lts --tags $tags
az webapp create --name $app2_name --resource-group $rg_name --plan appserviceplanwestus --runtime NODE:18-lts --tags $tags


az webapp show --name $app1_name --resource-group $rg_name --query "hostNames"
az webapp show --name $app2_name --resource-group $rg_name --query "hostNames"


az afd profile create --profile-name $fd_profile_name --resource-group $rg_name --sku Premium_AzureFrontDoor --tags $tags

#Add an endpoint
az afd endpoint create --resource-group $rg_name --endpoint-name $endpoint_name --profile-name $fd_profile_name --enabled-state Enabled


#Create an origin group
az afd origin-group create --resource-group $rg_name --origin-group-name $fd_orig_group_name --profile-name $fd_profile_name --enable-health-probe yes --probe-request-type GET --probe-protocol Http --probe-interval-in-seconds 60 --probe-path / --sample-size 4 --successful-samples-required 3 --additional-latency-in-milliseconds 50

#Add an origin 1 and 2 to the group
az afd origin create --resource-group $rg_name --host-name $app1_name.azurewebsites.net --profile-name $fd_profile_name --origin-group-name $fd_orig_group_name --origin-name primary-app --origin-host-header $app1_name.azurewebsites.net --priority 1 --weight 1000 --enabled-state Enabled --http-port 80 --https-port 443
az afd origin create --resource-group $rg_name --host-name $app2_name.azurewebsites.net --profile-name $fd_profile_name --origin-group-name $fd_orig_group_name --origin-name secondary-app --origin-host-header $app2_name.azurewebsites.net --priority 2 --weight 1000 --enabled-state Enabled --http-port 80 --https-port 443

#Add a route
az afd route create --resource-group $rg_name --profile-name $fd_profile_name --endpoint-name $endpoint_name --forwarding-protocol MatchRequest --route-name route --https-redirect Enabled --origin-group $fd_orig_group_name --supported-protocols Http Https --link-to-default-domain Enabled

echo "#curl to the app services"
curl -I $app1_name.azurewebsites.net
curl -I $app2_name.azurewebsites.net

echo "#Restrict access to web apps to the Azure Front Door instance"
echo "#At this point, you can still access your apps directly using their URLs at this point. To ensure traffic can only reach your apps through Azure Front Door, you set access restrictions on each of your apps. Front Door's features work best when traffic only flows through Front Door. You should configure your origins to block traffic that isn't sent through Front Door yet. Otherwise, traffic might bypass Front Door's web application firewall, DDoS protection, and other security features. Traffic from Azure Front Door to your applications originates from a well known set of IP ranges defined in the AzureFrontDoor.Backend service tag. By using a service tag restriction rule, you can restrict traffic to only originate from Azure Front Door."

front_door_id=$(az afd profile show --resource-group "$rg_name" --profile-name "$fd_profile_name" --query "frontDoorId" -o tsv)

echo "#Add the access restrictions to the web apps"
# az webapp config access-restriction add --resource-group $rg_name -n $app1_name --priority 100 --service-tag AzureFrontDoor.Backend --http-header x-azure-fdid=$front_door_id
# az webapp config access-restriction add --resource-group $rg_name -n $app2_name --priority 100 --service-tag AzureFrontDoor.Backend --http-header x-azure-fdid=$front_door_id

echo "#Test the Front Door"
endpoint_domain=$(az afd endpoint show --resource-group $rg_name --profile-name $fd_profile_name --endpoint-name $endpoint_name --query "hostName" -o tsv)

echo "#Purge the endpoint"
#az afd endpoint purge --resource-group $rg_name --profile-name $fd_profile_name --endpoint-name $endpoint_name --domains $endpoint_domain --content-paths '/*'

#Stop the web apps
# az webapp stop --name $app1_name --resource-group $rg_name
# az webapp stop --name $app2_name --resource-group $rg_name

# az webapp start --name $app1_name --resource-group $rg_name
# az webapp start --name $app2_name --resource-group $rg_name

####################################################################################################################################
#Create a new security policy
#Quickstart: Create an Azure Front Door Standard/Premium - the Azure CLI | Microsoft Learn
#https://learn.microsoft.com/en-us/azure/frontdoor/create-front-door-cli
####################################################################################################################################
waf_policy_name="myWAFPolicy$random_string"
security_policy_name="my-security-policy-$random_string"
az network front-door waf-policy create --name $waf_policy_name --resource-group $rg_name --sku Premium_AzureFrontDoor --disabled false --mode Prevention --redirect-url "https://docs.microsoft.com/en-us/azure/web-application-firewall" --tags $tags



echo "#Assign managed rules to the WAF policy"
az network front-door waf-policy managed-rules add --policy-name $waf_policy_name --resource-group $rg_name --type Microsoft_DefaultRuleSet --action Block --version 2.1
az network front-door waf-policy managed-rules add --policy-name $waf_policy_name --resource-group $rg_name --type Microsoft_BotManagerRuleSet --version 1.1

echo "#Create the security policy"
echo "#Now apply these two WAF policies to your Front Door by creating a security policy. This setting applies the Azure-managed rules to the endpoint that you defined earlier."
security_policy_domains=$(az afd endpoint show -g $rg_name --profile-name $fd_profile_name  --endpoint-name $endpoint_name --query "id" -o tsv)
waf_policy_id=$(az network front-door waf-policy show --name $waf_policy_name --resource-group $rg_name --query "id" -o tsv)
az afd security-policy create --resource-group $rg_name --profile-name $fd_profile_name --security-policy-name $security_policy_name --domains $security_policy_domains --waf-policy $waf_policy_id

#-------------------------------->

echo "#Create a demo exclusion rule"
az network front-door waf-policy managed-rules exclusion add --resource-group $rg_name --policy-name $waf_policy_name --type Microsoft_DefaultRuleSet --rule-group-id SQLI --rule-id 942230 --match-variable RequestHeaderNames --operator StartsWith --value user

echo "#Create a rate limiting rule"
rate_limit_rule_name="RateLimitRule1$random_string"
az network front-door waf-policy rule create --name $rate_limit_rule_name --policy-name $waf_policy_name --resource-group $rg_name --rule-type RateLimitRule --rate-limit-duration 1 --rate-limit-threshold 5 --action Block --priority 1 --defer

echo "#Add a match condition to the rate limiting rule"
az network front-door waf-policy rule match-condition add --match-variable QueryString --operator Contains --values 'promo' --name $rate_limit_rule_name --policy-name $waf_policy_name --resource-group $rg_name




echo "#Create a log analytics workspace"
log_analytics_workspace_name="myLogAnalyticsWorkspace$random_string"
az monitor log-analytics workspace create --resource-group $rg_name --workspace-name $log_analytics_workspace_name --location $region1 --tags $tags

#Get Log analytics workspace ID
law_id=$(az monitor log-analytics workspace show --resource-group $rg_name --workspace-name $log_analytics_workspace_name --query id -o tsv)
front_door_resource_id=$(az afd profile show --resource-group $rg_name --profile-name $fd_profile_name --query "id" -o tsv)

#Enable diagnostics logs on the Front Door
az monitor diagnostic-settings create --name "AzFDDiagnosticSettings" --resource $front_door_resource_id --resource-group $rg_name --workspace $law_id --logs '[{"category": "FrontdoorAccessLog", "enabled": true, "retentionPolicy": {"days": 0, "enabled": true}}, {"category": "FrontdoorWebApplicationFirewallLog", "enabled": true, "retentionPolicy": {"days": 0, "enabled": true}}, {"category": "FrontDoorHealthProbeLog", "enabled": true, "retentionPolicy": {"days": 0, "enabled": true}}]' --metrics '[{"category": "AllMetrics", "enabled": true, "retentionPolicy": {"days": 0, "enabled": true}}]' 

#az monitor diagnostic-settings list --resource $front_door_resource_id  -o table
#az monitor diagnostic-settings categories list --resource $front_door_resource_id


#Test the Front Door
echo "Front Door endpoint: $endpoint_domain"
echo "Web app 1: $app1_name.azurewebsites.net"
echo "Web app 2: $app2_name.azurewebsites.net"

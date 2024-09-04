
# Bash Script: Create a Multi-Region App - Azure App Service + Azure Front Door + WAF Policy

This guide provides instructions for creating a multi-region application using Azure App Service and Azure Front Door. The setup includes automatic routing for high availability and traffic management, as well as security configurations using Azure Web Application Firewall (WAF).

For more detailed steps, refer to the [official Microsoft tutorial](https://learn.microsoft.com/en-us/azure/app-service/tutorial-multi-region-app).

---

## Prerequisites

- Azure CLI installed.
- Azure subscription.
- Ensure you have necessary permissions for creating resource groups, app services, and security configurations.

---

## Variables

The script uses the following environment variables:

```bash
region1="eastus2"
region2="westus"
random_string=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 4)
rg_name="AZFD-MultiRegionApp-$random_string-RG"
fd_profile_name="my-enterprise-azfd-$random_string"
fd_orig_group_name="my-eshop-origin-group"
app1_name=myeshop-$random_string-$region1
app2_name=myeshop-$random_string-$region2
endpoint_name=my-eshop-endpoint-$random_string
```

> A random alphanumeric string is generated to create unique resource names.

---

## Steps

### 1. Create Resource Group

Create a resource group in the first region:

```bash
az group create --name $rg_name --location $region1 --tags 'delete'='yes'
```

### 2. Create App Service Plans

Create two app service plans, one in each region:

```bash
az appservice plan create --name "appserviceplaneastus2" --resource-group $rg_name --is-linux --location $region1
az appservice plan create --name "appserviceplanwestus" --resource-group $rg_name --is-linux --location $region2
```

### 3. Create Web Apps

Create two web apps, one for each region:

```bash
az webapp create --name $app1_name --resource-group $rg_name --plan appserviceplaneastus2 --runtime NODE:18-lts
az webapp create --name $app2_name --resource-group $rg_name --plan appserviceplanwestus --runtime NODE:18-lts
```

### 4. Retrieve Web App Hostnames

To get the hostnames of the web apps:

```bash
az webapp show --name $app1_name --resource-group $rg_name --query "hostNames"
az webapp show --name $app2_name --resource-group $rg_name --query "hostNames"
```

### 5. Create Azure Front Door Profile

Create an Azure Front Door profile to manage traffic:

```bash
az afd profile create --profile-name $fd_profile_name --resource-group $rg_name --sku Premium_AzureFrontDoor
```

### 6. Add Endpoint to Front Door

```bash
az afd endpoint create --resource-group $rg_name --endpoint-name $endpoint_name --profile-name $fd_profile_name --enabled-state Enabled
```

### 7. Create Origin Group

Create an origin group with health probes:

```bash
az afd origin-group create --resource-group $rg_name --origin-group-name $fd_orig_group_name --profile-name $fd_profile_name --enable-health-probe yes --probe-request-type GET --probe-protocol Http --probe-interval-in-seconds 60 --probe-path /
```

### 8. Add Origins

Add the two web apps as origins to the origin group:

```bash
az afd origin create --resource-group $rg_name --host-name $app1_name.azurewebsites.net --profile-name $fd_profile_name --origin-group-name $fd_orig_group_name --origin-name primary-app --origin-host-header $app1_name.azurewebsites.net --priority 1 --weight 1000
az afd origin create --resource-group $rg_name --host-name $app2_name.azurewebsites.net --profile-name $fd_profile_name --origin-group-name $fd_orig_group_name --origin-name secondary-app --origin-host-header $app2_name.azurewebsites.net --priority 2 --weight 1000
```

### 9. Add Route to Front Door

```bash
az afd route create --resource-group $rg_name --profile-name $fd_profile_name --endpoint-name $endpoint_name --forwarding-protocol MatchRequest --route-name route --https-redirect Enabled --origin-group $fd_orig_group_name --supported-protocols Http Https --link-to-default-domain Enabled
```

### 10. Restrict Access to Web Apps

To ensure that only Azure Front Door can access the web apps, restrict access using service tags:

```bash
front_door_id=$(az afd profile show --resource-group "$rg_name" --profile-name "$fd_profile_name" --query "frontDoorId" -o tsv)
az webapp config access-restriction add --resource-group $rg_name -n $app1_name --priority 100 --service-tag AzureFrontDoor.Backend --http-header x-azure-fdid=$front_door_id
az webapp config access-restriction add --resource-group $rg_name -n $app2_name --priority 100 --service-tag AzureFrontDoor.Backend --http-header x-azure-fdid=$front_door_id
```

### 11. Test the Setup

Test that both web apps are responding correctly through Front Door:

```bash
curl -I $app1_name.azurewebsites.net
curl -I $app2_name.azurewebsites.net
```

---

## Security Policies and WAF Configuration

### Create WAF Policy

Create a Web Application Firewall (WAF) policy:

```bash
waf_policy_name="myWAFPolicy$random_string"
az network front-door waf-policy create --name $waf_policy_name --resource-group $rg_name --sku Premium_AzureFrontDoor --mode Prevention
```

### Assign Managed Rules

Assign Microsoft default rules and BotManager rules to the WAF policy:

```bash
az network front-door waf-policy managed-rules add --policy-name $waf_policy_name --resource-group $rg_name --type Microsoft_DefaultRuleSet --version 2.1 --action Block
az network front-door waf-policy managed-rules add --policy-name $waf_policy_name --resource-group $rg_name --type Microsoft_BotManagerRuleSet --version 1.1
```

### Create Security Policy

Associate the WAF policy with the Azure Front Door endpoint:

```bash
security_policy_domains=$(az afd endpoint show -g $rg_name --profile-name $fd_profile_name --endpoint-name $endpoint_name --query "id" -o tsv)
waf_policy_id=$(az network front-door waf-policy show --name $waf_policy_name --resource-group $rg_name --query "id" -o tsv)
az afd security-policy create --resource-group $rg_name --profile-name $fd_profile_name --security-policy-name $security_policy_name --domains $security_policy_domains --waf-policy $waf_policy_id
```

---

## Final Notes

- **Purge Endpoint**: If you want to clear cache or reset the endpoint:
  ```bash
  az afd endpoint purge --resource-group $rg_name --profile-name $fd_profile_name --endpoint-name $endpoint_name --domains $endpoint_domain --content-paths '/*'
  ```

- **Stop or Start Web Apps**: Manage web app instances with:
  ```bash
  az webapp stop --name $app1_name --resource-group $rg_name
  az webapp stop --name $app2_name --resource-group $rg_name
  ```

---

This script automates the creation of a robust, multi-region Azure App Service setup, complete with Azure Front Door and WAF configurations for enhanced security and availability.

. ./Utils.ps1

$identityName = "powershell_test_identity"
$keyvaultName = "powershellTestKeyvault"
$rgRoles = @("Contributor", "Storage Blob Data Contributor", "Azure Event Hubs Data Receiver")
$subRoles = @("Storage Blob Data Reader", "Reader")
$resourceProviders = @("Microsoft.EventGrid", "Microsoft.Insights")
$subScope = "/subscriptions/"
$vnetName = "powershellVnet1"
$appSubnet = "appSubnet"

$randomIdentifier = Get-RandomIdentifier
$tag = @{script = "create-function-app-consumption-python"}
$storage = "stgaccpower$($randomIdentifier.ToLower())"
$functionAppNames = @(@{"gcapp-inventory-$randomIdentifier"="gcapp-inv-asp-$randomIdentifier"}, 
                        @{"gcapp-log-collector-$randomIdentifier"="gcapp-log-collector-asp-$randomIdentifier"},
                        @{"gcapp-management-$randomIdentifier"="gcapp-management-asp-$randomIdentifier"},
                        @{"gcapp-onboarding-$randomIdentifier"="gcapp-onboarding-asp-$randomIdentifier"},
                        @{"gcapp-policy-$randomIdentifier"="gcapp-policy-asp-$randomIdentifier"},
                        @{"gcapp-reveal-$randomIdentifier"="gcapp-reveal-asp-$randomIdentifier"},
                        @{"gcapp-topology-$randomIdentifier"="gcapp-topology-asp-$randomIdentifier"}
                    )
$skuStorage = "Standard_LRS"
$functionsVersion = 4
$pythonVersion = 3.9
$function_min_worker_count      = 1
$function_max_worker_count      = 2
$log_collector_max_worker_count = 20
$inv_max_worker_count           = 5


# Light House variables
$pathToTemplateFile = "rg.json"
$pathToParameterFile = "rg.parameters.json"
$PROD_SP_OBJECTID = "d26779cc-369f-47a4-870d-27d42fc02481"
$LAB_SP_OBJECTID = "2c530e6c-551e-4fa9-80ec-3df5b28fb68a"
$PROD_SP_NAME = "GC-CloudMs-Devops"
$LAB_SP_NAME = "GC-CloudMs-Lab"
$AKAMAI_GROUP ="azSecCloud_Ms_Devops"
$AKAMAI_GROUP_OBJECT_ID = "9d9630c5-722a-44f7-ac74-a8a015bae405"
$MANAGED_SERVICE_REGISTRATION_ASSIGNMENT_DELETE_ROLE =  "91c1777a-f3dc-4fae-b103-61d183457e46"
$CONTRIBUTOR_ROLE = "b24988ac-6180-42a0-ab88-20f7382dd24c"
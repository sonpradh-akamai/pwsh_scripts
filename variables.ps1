$identityName = "powershell_test_identity"
$keyvaultName = "powershellTestKeyvault"
$rgRoles = @("Contributor", "Storage Blob Data Contributor", "Azure Event Hubs Data Receiver")
$subRoles = @("Storage Blob Data Reader", "Reader")
$resourceProviders = @("Microsoft.EventGrid", "Microsoft.Insights")
$subScope = "/subscriptions/"


$randomIdentifier = Get-Random
$tag = @{script = "create-function-app-consumption-python"}
#$storage = "stgaccpower$randomIdentifier"
$storage = "stgaccpowersh994"
$functionAppNames = @("gcc-inventory-service", "gcc-flowlog-collector", "gcc-management-service", "gcc-onboarding-service", "gcc-policy-service", "gcc-reveal-service", "gcc-topology-service")
#$functionApp = "functpower-$randomIdentifier"
$functionApp = "ffunctpower-1454944999"
$skuStorage = "Standard_LRS"
$functionsVersion = "4"
$pythonVersion = "3.9"


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
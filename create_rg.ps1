# Get user inputs
# $resourceGroupName = Read-Host -Prompt "Enter the Azure Resource Group name"
# $location = Read-Host -Prompt "Enter the location for the Resource Group"
# $identityName = Read-Host -Prompt "Enter the User-Managed Identity name"

$resourceGroupName = "powershell-test-rg"
$location = "eastus"
$identityName = "powershell_test_identity"
$keyvaultName = "powershellTestKeyvault"
$functionAppNames = @("funcpowersh-1454944994", "funcpowersh-1454944995", "funcpowersh-1454944996")
$rgRoles = @("Contributor", "Storage Blob Data Contributor", "Azure Event Hubs Data Receiver")
$subRoles = @("Storage Blob Data Reader", "Reader")
$subScope = "/subscriptions/ea21d634-a6d3-4fb5-8ee8-9bf23b7c95a1"
$resourceProviders = @("Microsoft.EventGrid", "Microsoft.Insights")
$gcappRoleName = "GCAppPowershellRole"

# Variable block
$randomIdentifier = Get-Random
$tag = @{script = "create-function-app-consumption-python"}
#$storage = "stgaccpower$randomIdentifier"
$storage = "stgaccpowersh994"
#$functionApp = "functpower-$randomIdentifier"
$functionApp = "ffunctpower-1454944999"
$skuStorage = "Standard_LRS"
$functionsVersion = "4"
$pythonVersion = "3.9" #Allowed values: 3.7, 3.8, and 3.9



# If installed, connect to Azure account
#Connect-AzAccount

# Check if the resource group already exists
$ResourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

if ($ResourceGroup -eq $null) {
    # Resource group does not exist, create it
    $ResourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $location
    Write-Host "Azure Resource Group '$resourceGroupName' created successfully in location '$location'."
} else {
    # Resource group already exists
    Write-Host "Azure Resource Group '$resourceGroupName' already exists."
}

# Check if the identity already exists
$identity = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $identityName -ErrorAction SilentlyContinue

if ($identity -eq $null) {
    # Identity does not exist, create it
    $identity = New-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $identityName -Location $location
    Write-Host "User-Managed Identity '$identityName' created successfully in Resource Group '$resourceGroupName'."
} else {
    # Identity already exists
    Write-Host "User-Managed Identity '$identityName' already exists in Resource Group '$resourceGroupName'."
}

$role = New-Object -TypeName Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition 
$role.Name = $gcappRoleName
$role.Description = "Custom Role for Micro-segmentation."
$role.IsCustom = $true
$role.AssignableScopes = @($subScope)
$role.Actions = @(                    
                "Microsoft.EventGrid/register/action",
                "Microsoft.EventGrid/eventSubscriptions/write",
                "Microsoft.EventGrid/eventSubscriptions/delete"
            )

# Check if the role already exists
$gcappRole = Get-AzRoleDefinition $gcappRoleName

if ($gcappRole -eq $null) {
    $gcappRole = New-AzRoleDefinition -Role $role
    Write-Host "$gcappRoleName role created."
} else {
    Write-Host "$gcappRoleName is already exits. Updating"
    $gcappRole.AssignableScopes = $role.AssignableScopes
    Set-AzRoleDefinition -Role $gcappRole
}

$roleAssignment = Get-AzRoleAssignment -ObjectId $identity.PrincipalId -Scope $subScope -RoleDefinitionId $gcappRole.Id -ErrorAction SilentlyContinue
if ($roleAssignment -eq $null) {
    $roleAssignment = New-AzRoleAssignment -ObjectId $identity.PrincipalId -RoleDefinitionId $gcappRole.Id -Scope $subScope
    Write-Host "$gcappRoleName role assigned to User-Managed Identity '$identityName' for subscription '$subScope'."
} else {
    Write-Host "$gcappRoleName is already assigned to User-Managed Identity '$identityName' for subscription '$subScope'."
}


# Iterate through the list and assign subscription level roles
foreach ($roleName in $subRoles) {

    # Check if role is already assigned to the identity
    $roleAssignment = Get-AzRoleAssignment -ObjectId $identity.PrincipalId -Scope $subScope -RoleDefinitionName $roleName -ErrorAction SilentlyContinue

    if ($roleAssignment -eq $null) {
        $roleAssignment = New-AzRoleAssignment -ObjectId $identity.PrincipalId -RoleDefinitionName $roleName -Scope $subScope
        Write-Host "$roleName role assigned to User-Managed Identity '$identityName' for subscription '$subScope'."
    } else {
        Write-Host "$roleName is already assigned to User-Managed Identity '$identityName' for subscription '$subScope'."
    }

}

# Iterate through the list and assign resource group level roles
foreach ($roleName in $rgRoles) {

    # Check if role is already assigned to the identity
    $roleAssignment = Get-AzRoleAssignment -ObjectId $identity.PrincipalId -ResourceGroupName $resourceGroupName -RoleDefinitionName $roleName -ErrorAction SilentlyContinue

    if ($roleAssignment -eq $null) {
        $roleAssignment = New-AzRoleAssignment -ObjectId $identity.PrincipalId -RoleDefinitionName $roleName -ResourceGroupName $resourceGroupName
        Write-Host "$roleName role assigned to User-Managed Identity '$identityName' for Resource Group '$resourceGroupName'."
    } else {
        Write-Host "$roleName is already assigned to User-Managed Identity '$identityName' in Resource Group '$resourceGroupName'."
    }

}

#add access to TenantLevelAccessCloudMSDev
# Check if the keyvault already exists
$keyvault = Get-AzKeyVault -ResourceGroupName $resourceGroupName -Name $keyvaultName -ErrorAction SilentlyContinue

if ($keyvault -eq $null) {
    # keyvault does not exist, create it
    $keyvault = New-AzKeyVault -ResourceGroupName $resourceGroupName -Name $keyvaultName -Location $location
    Write-Host "Keyvault '$keyvaultName' created successfully in Resource Group '$resourceGroupName'."

    # Assign permissions to Key Vault for the Managed Identity
    $accessPolicy = Set-AzKeyVaultAccessPolicy -VaultName $keyvaultName -ResourceGroupName $resourceGroupName -ObjectId $identity.PrincipalId -PermissionsToSecrets all -BypassObjectIdValidation
    Write-Host "User-Managed Identity '$identityName' assigned to Key Vault '$keyvaultName' with necessary permissions."

} else {
    # keyvault already exists
    Write-Host "keyvault '$keyvaultName' already exists in Resource Group '$resourceGroupName'."
}


$stgacc = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storage -ErrorAction SilentlyContinue
if ($stgacc -eq $null) {
    # stgacc does not exist, create it
    $stgacc = New-AzStorageAccount -Name $storage -Location $location -ResourceGroupName $resourceGroupName -SkuName $skuStorage
    Write-Host "stgacc '$storage' created successfully in Resource Group '$resourceGroupName'."
} else {
    # stgacc already exists
    Write-Host "stgacc '$storage' already exists in Resource Group '$resourceGroupName'."
}

# Iterate through the list and create Function Apps
foreach ($functionAppName in $functionAppNames) {
    # Check if the Function App already exists
    $existingFunctionApp = Get-AzFunctionApp -ResourceGroupName $resourceGroupName -Name $functionAppName -ErrorAction SilentlyContinue

    if ($existingFunctionApp -eq $null) {
        # Function App does not exist, create it
        New-AzFunctionApp -Name $functionAppName -StorageAccountName $storage -Location $location -ResourceGroupName $resourceGroupName -OSType Linux -Runtime Python -RuntimeVersion `
            $pythonVersion -FunctionsVersion $functionsVersion -IdentityID $identity.Id -IdentityType UserAssigned
        Write-Host "Azure Function App '$functionAppName' created successfully in Resource Group '$resourceGroupName'."
    } else {
        # Function App already exists
        Write-Host "Azure Function App '$functionAppName' already exists in Resource Group '$resourceGroupName'."
    }
}

# Register for resource provider
foreach ($resourceProvider in $resourceProviders) {
    Register-AzResourceProvider -ProviderNamespace $resourceProvider
    Write-Host "Registered for resource provider: $resourceProvider"
}

# Create lighthouse offer
$deploymentName = "GCAPP_POWERSHELL_OFFER"
$pathToTemplateFile = "rg.json"
$pathToParameterFile = "rg.parameters.json"
New-AzSubscriptionDeployment -Name $deploymentName `
                 -Location $location `
                 -TemplateFile $pathToTemplateFile `
                 -TemplateParameterFile $pathToParameterFile `
                 -Verbose

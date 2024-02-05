# Get user inputs
param (
    [Parameter(Mandatory=$true)][string]$client_id,
    [Parameter(Mandatory=$true)][string]$client_secret,
    [Parameter(Mandatory=$true)][string]$location,
    [Parameter(Mandatory=$true)][string]$subscription_id,
    [string]$resourceGroupName = "Powershell-rg",
    [string]$gcappRoleName = "GCAppRole",
    [string]$offername = "GCAPP_POWERSHELL_OFFER"
)

. ./Variables.ps1
$subScope = $subScope + $subscription_id

# If installed, connect to Azure account
#Connect-AzAccount

function New-ResourceGroup () {
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
}

function New-ManagedIdentity () {
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
    return $identity
}

function New-CustomRole () {
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
    } 
    else {
        Write-Host "$gcappRoleName role already exits. Updating"
        $gcappRole.AssignableScopes = $role.AssignableScopes
        $gcappRole.Actions = $role.Actions
        Set-AzRoleDefinition -Role $gcappRole
    }

    return $gcappRole
}

function Add-CustomRole ($identity) {
    Write-Host "Received param for Add-CustomRole: {$($identity.name)}"
    $gcappRole = Get-AzRoleDefinition $gcappRoleName
    $roleAssignment = Get-AzRoleAssignment -ObjectId $identity.PrincipalId -Scope $subScope -RoleDefinitionId $gcappRole.Id -ErrorAction SilentlyContinue
    if ($roleAssignment -eq $null) {
        $roleAssignment = New-AzRoleAssignment -ObjectId $identity.PrincipalId -RoleDefinitionId $gcappRole.Id -Scope $subScope
        Write-Host "$gcappRoleName role assigned to User-Managed Identity '$identityName' for subscription '$subScope'."
    } else {
        Write-Host "$gcappRoleName is already assigned to User-Managed Identity '$identityName' for subscription '$subScope'."
    }
}

function Add-SubsRole ($identity, $roleName) {
    Write-Host "Received param for Add-SubsRole: {$($identity.name)}, {$roleName}"
    # Check if role is already assigned to the identity
    $roleAssignment = Get-AzRoleAssignment -ObjectId $identity.PrincipalId -Scope $subScope -RoleDefinitionName $roleName -ErrorAction SilentlyContinue

    if ($roleAssignment -eq $null) {
        $roleAssignment = New-AzRoleAssignment -ObjectId $identity.PrincipalId -RoleDefinitionName $roleName -Scope $subScope
        Write-Host "$roleName role assigned to User-Managed Identity '$identityName' for subscription '$subScope'."
    } else {
        Write-Host "$roleName is already assigned to User-Managed Identity '$identityName' for subscription '$subScope'."
    }
}

function Add-RgRole ($identity, $roleName) {
    Write-Host "Received param for Add-RgRole: {$($identity.name)}, {$roleName}"
    # Check if role is already assigned to the identity
    $roleAssignment = Get-AzRoleAssignment -ObjectId $identity.PrincipalId -ResourceGroupName $resourceGroupName -RoleDefinitionName $roleName -ErrorAction SilentlyContinue

    if ($roleAssignment -eq $null) {
        $roleAssignment = New-AzRoleAssignment -ObjectId $identity.PrincipalId -RoleDefinitionName $roleName -ResourceGroupName $resourceGroupName
        Write-Host "$roleName role assigned to User-Managed Identity '$identityName' for Resource Group '$resourceGroupName'."
    } else {
        Write-Host "$roleName is already assigned to User-Managed Identity '$identityName' in Resource Group '$resourceGroupName'."
    }
}

function New-KeyVault ($identity) {
    Write-Host "Received param for  New-KeyVault: {$($identity.name)}"
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
}

function New-StorageAccount () {
    $stgacc = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storage -ErrorAction SilentlyContinue
    if ($stgacc -eq $null) {
        # stgacc does not exist, create it
        $stgacc = New-AzStorageAccount -Name $storage -Location $location -ResourceGroupName $resourceGroupName -SkuName $skuStorage
        Write-Host "stgacc '$storage' created successfully in Resource Group '$resourceGroupName'."
    } else {
        # stgacc already exists
        Write-Host "stgacc '$storage' already exists in Resource Group '$resourceGroupName'."
    }
}

function New-FunctionApp ($identity, $functionAppName, $appServicePlanName) {
    Write-Host "Received param for New-FunctionApp: {$($identity.name)}, {$functionAppName}, {$appServicePlanName}"
    $existingFunctionAppPlan = Get-AzFunctionAppPlan -ResourceGroupName $resourceGroupName -Name $appServicePlanName -ErrorAction SilentlyContinue

    if ($existingFunctionAppPlan -eq $null) {
        # Function App does not exist, create it
        New-AzFunctionAppPlan -Name $appServicePlanName -Location $location -ResourceGroupName $resourceGroupName -Sku EP1 `
                 -WorkerType Linux -MinimumWorkerCount 1 -MaximumWorkerCount 2
        Write-Host "Azure Function App plan '$appServicePlanName' created successfully in Resource Group '$resourceGroupName'."
    } else {
        # Function App already exists
        Write-Host "Azure Function App plan '$appServicePlanName' already exists in Resource Group '$resourceGroupName'."
    }    

    # Check if the Function App already exists
    $existingFunctionApp = Get-AzFunctionApp -ResourceGroupName $resourceGroupName -Name $functionAppName -ErrorAction SilentlyContinue

    if ($existingFunctionApp -eq $null) {
        # Function App does not exist, create it
        $functionApp = New-AzFunctionApp -Name $functionAppName `
                                            -ResourceGroupName $resourceGroupName `
                                            -PlanName $appServicePlanName `
                                            -StorageAccountName $storage `
                                            -Runtime Python -OSType Linux -FunctionsVersion $functionsVersion -RuntimeVersion $pythonVersion `
                                            -IdentityID $identity.Id -IdentityType UserAssigned
        Write-Host "Azure Function App '$functionAppName' created successfully in Resource Group '$resourceGroupName'."
    } else {
        # Function App already exists
        Write-Host "Azure Function App '$functionAppName' already exists in Resource Group '$resourceGroupName'."
    }
}

function Register-ResourceProvider($resourceProvider) {
    Write-Host "Received param for Register-ResourceProvider: {$resourceProvider}"
    Register-AzResourceProvider -ProviderNamespace $resourceProvider
    Write-Host "Registered for resource provider: $resourceProvider"
}

# Create lighthouse offer
function Get-Auth () {
    $auth_values = @(
        [ordered]@{
            "principalId"= $AKAMAI_GROUP_OBJECT_ID
            "roleDefinitionId"= $CONTRIBUTOR_ROLE
            "principalIdDisplayName"= $AKAMAI_GROUP
        };
        [ordered]@{
            "principalId"=$AKAMAI_GROUP_OBJECT_ID
            "roleDefinitionId"= $MANAGED_SERVICE_REGISTRATION_ASSIGNMENT_DELETE_ROLE
            "principalIdDisplayName"= $AKAMAI_GROUP
        };
        [ordered]@{
            "principalId"= $LAB_SP_OBJECTID
            "roleDefinitionId"= $CONTRIBUTOR_ROLE
            "principalIdDisplayName"= $LAB_SP_NAME
        };
        [ordered]@{
            "principalId"= $LAB_SP_OBJECTID
            "roleDefinitionId"= $MANAGED_SERVICE_REGISTRATION_ASSIGNMENT_DELETE_ROLE
            "principalIdDisplayName"= $LAB_SP_NAME
        };
    )

    return $auth_values
}

function Update-PramFile () {
    # Read the content of the JSON file
    $jsonContent = Get-Content -Path $pathToParameterFile -Encoding UTF8 | ConvertFrom-Json

    # Modify the fields as needed
    $auth_values = Get-Auth
    $jsonContent.parameters.rgName.value = $resourceGroupName
    $jsonContent.parameters.mspOfferName.value = $offername
    $jsonContent.parameters.authorizations.value = $auth_values

    # Save the updated JSON back to the file
    $jsonContent | ConvertTo-Json -depth 20 | Set-Content -Path $pathToParameterFile -NoNewLine -Encoding UTF8
}

function New-LighthouseDeployment () {
    New-AzSubscriptionDeployment -Name $offername `
        -Location $location `
        -TemplateFile $pathToTemplateFile `
        -TemplateParameterFile $pathToParameterFile `
        -Verbose
}

function New-VirtualNetwork () {
    $appSubnet = New-AzVirtualNetworkSubnetConfig -Name $appSubnet -AddressPrefix "10.0.1.0/24"
    New-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix "10.0.0.0/16" -Subnet $appSubnet    
}

function Set-SubnetDelegation() {
    $virtualNetwork = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name $appSubnet -VirtualNetwork $virtualNetwork
    Add-AzDelegation -Name "functionAppDelegation" `
        -ServiceName "Microsoft.Web/serverFarms" `
        -Subnet $subnet

    Set-AzVirtualNetwork -VirtualNetwork $virtualNetwork
}

function Add-VnetIntegration($functionAppName) {
    $virtualNetwork = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name $appSubnet -VirtualNetwork $virtualNetwork
    Write-Host "subnet_id '$($subnet.Id)'."
    $functionApp = Get-AzResource -ResourceType Microsoft.Web/sites -ResourceGroupName $resourceGroupName -ResourceName $functionAppName
    Write-Host "func_id '$($functionApp.Id)'."
    $functionApp.Properties.virtualNetworkSubnetId = $subnet.Id
    $functionApp.Properties.vnetRouteAllEnabled = 'true'
    $functionApp | Set-AzResource -Force
}

New-ResourceGroup
$identity = New-ManagedIdentity
Write-Host "15 seconds sleep started"
Start-Sleep -Seconds 15
Write-Host "sleep finsihed"
Add-CustomRole $identity

# Iterate through the list and assign subscription level roles
foreach ($roleName in $subRoles) {
    Add-SubsRole $identity $roleName
}

# Iterate through the list and assign resource group level roles
foreach ($roleName in $rgRoles) {
    Add-RgRole $identity $roleName
}

New-KeyVault $identity
New-StorageAccount 
New-VirtualNetwork
Set-SubnetDelegation

# Iterate through the list and create Function Apps
foreach ($functionAppName in $functionAppNames) {
    foreach ($functionApp in $functionAppName.Keys) {
        $appServicePlanName = $functionAppName[$functionApp]
        
        Write-Host "$functionApp : $appServicePlanName"
        New-FunctionApp $identity $functionApp $appServicePlanName
        Add-VnetIntegration $functionApp
    }
}

# Register for resource provider
foreach ($resourceProvider in $resourceProviders) {
    Register-ResourceProvider $resourceProvider
}

Update-PramFile
New-LighthouseDeployment
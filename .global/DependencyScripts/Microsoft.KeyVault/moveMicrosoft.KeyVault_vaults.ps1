# Pre-requisite: Please install the Azure CLI using - https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli

# Access Reqiurments: A contribute access is required to both the source and target keyvaults. Along with a get access policy on the source and a set access policy on the target keyvault.

#  Description: With this approach, we're simplifying fetching all secrets from Vault1 (Source) in Subscription1, 
#  and saving them to Vault2 (Target) in Subscription2. 
#  Mandatory Parameters are the - source/origin vault name and subscription guid, - target/destination 
#  vault name and subscription guid, and - disableDestinationSecrets to create secret in disabled state

# Here's how you call the script:
# .\moveMicrosoft.KeyVault_vaults.ps1 -branchName ${{ parameters.branchName }}

Param(
    [parameter(mandatory)] [string] $branchName
)

$originVault = ""
$originSubscriptionId = ""
$destinationVault = ""
$destinationSubscriptionId = ""
$disableDestinationSecrets = $false
$executeScript = $true

function moveMicrosoft.KeyVault_vaults{
Param(
    [parameter(mandatory)] [string] $originVault,
    [parameter(mandatory)] [string] $originSubscriptionId,
    [parameter(mandatory)] [string] $destinationVault,
    [parameter(mandatory)] [string] $destinationSubscriptionId,
    [string] $disableDestinationSecrets = $false,
    [parameter(mandatory)] [string] $branchName
)

try{
    
# 1. Set the source subscription id. 
Write-Host "Setting origin subscription to: $($originSubscriptionId)..."
az account set -s $originSubscriptionId

# 1.1 Get all secrets
Write-Host "Listing all origin secrets from vault: $($originVault)"
$originSecretKeys = az keyvault secret list --vault-name $originVault  -o json --query "[].name"  | ConvertFrom-Json

# 1.3 Loop secrets into PSCustomObjects, making it easy to work with later.
$secretObjects = $originSecretKeys | ForEach-Object {
    Write-Host " - Getting secret value for '$($_)'"
    $secret = az keyvault secret show --name $_ --vault-name $originVault -o json | ConvertFrom-Json
    
    [PSCustomObject]@{
        secretName  = $_;
        secretValue = $secret.value;
    }#endcustomobject.

}#endforeach.

Write-Host "Done fetching secrets..."

# 2. Set the destination subscription id.
Write-Host "Setting destination subscription to: $($destinationSubscriptionId)..."
az account set -s $destinationSubscriptionId

# 2.2 Loop secrets objects, and set secrets in destination vault
Write-Host "Writing all destination secrets to vault: $($destinationVault)"
$secretObjects | ForEach-Object {
    Write-Host " - Setting secret value for '$($_.secretName)'"
    az keyvault secret set --vault-name $destinationVault --name "$($_.secretName)" --value  "$($_.secretValue)" --disabled $disableDestinationSecrets -o none
}

# 3. Clean up
Write-Host "Cleaning up and exiting."
Remove-Variable secretObjects
Remove-Variable originSecretKeys

Write-Host "Finished."

}
catch{
$statePath = $pwd
Import-Module "$statePath/src/internal/functions/Log-Exceptions.ps1" -Force 
$scriptPath= ($MyInvocation.MyCommand).Definition
$scriptName= ([io.fileinfo]$MyInvocation.MyCommand.Definition).BaseName

$settinglocation=(Get-ChildItem -Path "$statePath/src/").Name
foreach($locationfile in $settinglocation){
if($locationfile -match "_Settings.json")
{
$settingfile=get-content -path "$statePath/src/$locationfile"
$logPath=($settingfile | ConvertFrom-Json).RelocationSettings.LogPath 
}
}
$Result = ""
if($Error.Count){ $Result = "Failed"}
Log-Exceptions -ScriptName $scriptName -LogPath "$statePath/$logPath" -Exception "$PSItem.Exception.Message" -Result $Result -ScriptPath $scriptPath -branchName $branchName
}
}

if($executeScript -eq $true)
{
moveMicrosoft.KeyVault_vaults -originVault $originVault -originSubscriptionId $originSubscriptionId -destinationVault $destinationVault -destinationSubscriptionId $destinationSubscriptionId -branchName $branchName
}



# Pre-requisite: Please install the Azure CLI using - https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli

# Access Reqiurments: A contribute access is required to both the source and target storage accounts. 

#  Description: With this approach, we're integrating Application insights and storage account to app service. Please set isFunctionApp flag to true for function app
# Here's how you call the script:
# .\moveMicrosoft.Web_sites.ps1 -branchName ${{ parameters.branchName }}

param(
    [String]$branchName
)
# Function app and storage account names must be unique.

# Variable block
$targetSubscriptionId=""
$location=""
$resourceGroup=""
$app=""
$applicationInsightsAgentVersion=""
$isFunctionApp = $true #Set to false if it is web app
$executeScript = $true
# Below varisbles not required for web app
$tag=""
$storage=""
$functionsWorkerRuntime=""
$skuStorage=""
$functionsVersion=""


function moveMicrosoft.Web_sites{
param(
    [parameter(mandatory)] [string] $branchName,
    [String]$targetSubscriptionId,
    [String]$location,
    [String]$resourceGroup,
    [String]$tag,
    [String]$storage,
    [String]$app,
    [String]$skuStorage,
    [String]$functionsVersion,
    [String]$functionsWorkerRuntime,
    [String]$applicationInsightsAgentVersion
)
try
{
# Set target subscription
Write-Host "Setting origin subscription to: $($targetSubscriptionId)..."
az account set -s $targetSubscriptionId

if($isFunctionApp -eq $true) {
echo "This is a function app"    
# Create an Azure storage account in the resource group.
echo "Creating $storage"
az storage account create --name $storage --location "$location" --resource-group $resourceGroup --sku $skuStorage

# Get the storage account connection string. 
$connstr=$(az storage account show-connection-string --name $storage --resource-group $resourceGroup --query connectionString --output tsv)
$saconn=az storage account show-connection-string -g $resourceGroup -n $storage --query connectionString --output tsv
$websitestr=az storage account show-connection-string -g $resourceGroup -n $storage --query connectionString --output tsv

# Update function app settings to connect to the storage account.
az functionapp config appsettings set --name $app --resource-group $resourceGroup --settings "AzureWebJobsStorage=$saconn"
az functionapp config appsettings set --name $app --resource-group $resourceGroup --settings "StorageConStr=$connstr"

#Update functions worker runtime
az functionapp config appsettings set --name $app --resource-group $resourceGroup --settings "functions_worker_runtime=$functionsWorkerRuntime"
}
else {
    echo "This is web app"
}

# Update function app settings to connect to the Application Insights.
$appInsightsKey = az resource show -g $resourceGroup -n $app --resource-type "Microsoft.Insights/components" --query "properties.InstrumentationKey" -o tsv
az webapp config appsettings set -n $app -g $resourceGroup --settings "APPINSIGHTS_INSTRUMENTATIONKEY=$appInsightsKey"
az webapp config appsettings set -n $app -g $resourceGroup --settings "ApplicationInsightsAgent_EXTENSION_VERSION=$applicationInsightsAgentVersion"
}

catch
{
    echo "catch block"
$statePath = $pwd
Import-Module $statePath\src\internal\functions\Log-Exceptions.ps1 -Force
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
Write-Host "currently in catch block"
Write-Host "$PSItem.Exception.Message"
Write-Host $Result
Write-Host $Error
Log-Exceptions -ScriptName $scriptName -LogPath $logPath -Exception "$PSItem.Exception.Message" -Result $Result -ScriptPath $scriptPath -branchName $branchName
}
}
if($executeScript -eq $true)
{
echo "executeScript "    
moveMicrosoft.Web_sites -branchName $branchName -targetSubscriptionId $targetSubscriptionId -location $location -resourceGroup $resourceGroup -tag $tag -storage $storage -app $app -skuStorage $skuStorage -functionsVersion $functionsVersion -functionsWorkerRuntime $functionsWorkerRuntime -applicationInsightsAgentVersion $applicationInsightsAgentVersion
}
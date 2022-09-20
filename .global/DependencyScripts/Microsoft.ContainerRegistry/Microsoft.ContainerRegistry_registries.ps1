# Pre-requisite: Please install the Azure CLI using - https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli

# Access Reqiurments: SPN to be created to access the subscriptions

#  Description: This is basically exporting of the repositories and images along with tags from source Container registry to the target container registry.
#  Mandatory Parameters are the - Sourceacr, targetacr, $sourcespnid, $spnpassword


# Here's how you call the script:
# .\moveMicrosoft.containerregistry.ps1 -branchName ${{ parameters.branchName }}

Param(
    [parameter(mandatory)] [string] $branchName
)

# This script is to move the Repository and its images along with tags from the source container registry to the Target Container Registry
# Tested for cross subscription

# Variables
$Sourceacr = "arppsourceacr"
$targetacr ="arpptargetacr"
$executeScript = $true

# Extraction of manifests and images from Source acr
function moveMicrosoft.containerregistry
{
param(
    [String]$Sourceacr,
    [String]$targetacr
)

Try
{
$Sourceacr = "arppsourceacr"
$targetacr ="arpptargetacr"
$images = az acr repository list -n $Sourceacr
$repos = $images|convertfrom-json
$sourceuri = "${Sourceacr}.azurecr.io/"
foreach ($image in $repos)
{
    write-host "The image being processed is" $image
    $mf = az acr repository show-manifests -n $Sourceacr --repository $image
    $tgjson = $mf |convertfrom-json
    $tags = $tgjson.tags
    foreach ($tag in $tags)
    {
    $repo = "${sourceuri}${image}:${tag}"
    Write-host "Processing" $repo
    $imagetag = "${image}:${tag}"
    Write-host "Processing image" $imagetag
    az acr import --name $targetacr --source $repo --image $imagetag
    }
}
}
Catch
{
	   echo "catch block of Import to target"
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
echo "ExecuteScript for Azure Container registry - Import Repository"    
moveMicrosoft.containerregistry $Sourceacr $targetacr
}

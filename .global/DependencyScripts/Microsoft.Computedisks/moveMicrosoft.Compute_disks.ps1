# Pre-requisite: Please install the Azure CLI using - https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli
# Install the latest version of azcopy using -https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10#download-azcopy
# Disk should be unattached or VM should be in deallocate state if it is attached to VM
# Install the Az modules using : https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-7.4.0
# In the parameters file of this resource , change the "value" of "deployState_Microsoft.Compute_disks_0" from "Yes" to "No"

# Access Reqiurments: A contribute access is required to both the source and target subscription.
# Description: With this approach, we're creating disk (OS and data) in the target subscription.Once disk is created,it reads the data from Source disk in Subscription1, 
# and writing it to target disk in Subscription2.
# Mandatory Parameters are listed below

# Here's how you call the script:
# .\moveMicrosoft.Compute_disks.ps1 -branchName ${{ parameters.branchName }}

Param(
    [parameter(mandatory)] [string] $branchName
)

$originSubscriptionId = ""
$destinationSubscriptionId = ""
$sourceRG = ""
$targetRG = ""
$sourceDiskName = ""
$targetDiskName = ""
$targetLocate = ""
$SkuName = ""
$targetOS = "" # This parameter is used when relocating OS disk only.#Expected value for OS is either "Windows" or "Linux"
$HyperVGeneration = "" # This parameter is used when relocating OS disk only.#Expected value is "V1" or "V2"
$executeScript = $true

function moveMicrosoft.Compute_disks{
    Param(
   
    [parameter(mandatory)] [string] $originSubscriptionId,
    [parameter(mandatory)] [string] $destinationSubscriptionId,
    [parameter(mandatory)] [string] $sourceRG,
    [parameter(mandatory)] [string] $targetRG,
    [parameter(mandatory)] [string] $sourceDiskName,
    [parameter(mandatory)] [string] $targetDiskName,
    [parameter(mandatory)] [string] $branchName
    
)

try {
    
# 1. Set the source subscription id. 
Write-Host "Setting origin subscription to: $($originSubscriptionId)..."
Set-AzContext -SubscriptionId "$originSubscriptionId" | Out-Null

$sourceDisk = Get-AzDisk -ResourceGroupName $sourceRG -DiskName $sourceDiskName

# Adding the sizeInBytes with the 512 offset, and the -Upload flag
$targetDiskconfig = New-AzDiskConfig -SkuName $SkuName -osType $targetOS -UploadSizeInBytes $($sourceDisk.DiskSizeBytes+512) -Location $targetLocate -CreateOption 'Upload' -HyperVGeneration $HyperVGeneration

# Get a SAS token for the source disk, so that AzCopy can read it
$sourceDiskSas = Grant-AzDiskAccess -ResourceGroupName $sourceRG -DiskName $sourceDiskName -DurationInSecond 86400 -Access 'Read'

# 2. Set the destination subscription id. 
Write-Host "Setting destination subscription to: $($destinationSubscriptionId)..."
Set-AzContext -SubscriptionId "$destinationSubscriptionId" | Out-Null


$targetDisk = New-AzDisk -ResourceGroupName $targetRG -DiskName $targetDiskName -Disk $targetDiskconfig

# Get a SAS token for the target disk, so that AzCopy can write to it
$targetDiskSas = Grant-AzDiskAccess -ResourceGroupName $targetRG -DiskName $targetDiskName -DurationInSecond 86400 -Access 'Write'

# Begin the copy!
azcopy copy $sourceDiskSas.AccessSAS $targetDiskSas.AccessSAS --blob-type PageBlob

# Revoke the SAS so that the disk can be used by a VM
Revoke-AzDiskAccess -ResourceGroupName $targetRG -DiskName $targetDiskName

# 3. Set the source subscription id. 
Write-Host "Setting origin subscription to: $($originSubscriptionId)..."
Set-AzContext -SubscriptionId "$originSubscriptionId" | Out-Null

# Revoke the SAS so that the disk can be used by a VM
Revoke-AzDiskAccess -ResourceGroupName $sourceRG -DiskName $sourceDiskName

}
catch{
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
moveMicrosoft.Compute_disks -sourceDiskName $sourceDiskName -originSubscriptionId $originSubscriptionId -sourceRG $sourceRG -targetDiskName $targetDiskName -destinationSubscriptionId $destinationSubscriptionId -targetRG $targetRG -branchName $branchName
}
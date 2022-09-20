# Pre-requisite: Please install the Azure CLI using - https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli

# Access Reqiurments: A contribute access is required to both the source and target keyvaults. Along with a get access policy on the source and a set access policy on the target keyvault.

#  Description: With this approach, we're simplifying fetching all secrets from Vault1 (Source) in Subscription1, 
#  and saving them to Vault2 (Target) in Subscription2. 
#  Mandatory Parameters are the - source/origin vault name and subscription guid, - target/destination 
#  vault name and subscription guid, and - disableDestinationSecrets to create secret in disabled state

# Here's how you call the script:
# .\moveMicrosoft.Compute_virtualMachines.ps1 -branchName ${{ parameters.branchName }}

param
    (
         # SOURCE PARAMS FROM COMMANDLINE (In Tenant A)
         [Parameter(Mandatory=$true, Position=0)]
         [string] $sourceAppId,
         [Parameter(Mandatory=$true, Position=1)]
         [string] $sourceStringPwd,
         [Parameter(Mandatory=$true, Position=2)]
         [string] $sourceTenantId,
         [Parameter(Mandatory=$true, Position=3)]
         [string] $sourceSubscriptionId,
         [Parameter(Mandatory=$true, Position=4)]
         [string] $sourceVmName,
         [Parameter(Mandatory=$true, Position=5)]
         [string] $sourceVmResourceGroup,

         # DESTINATION PARAMS FROM COMMANDLINE (In Tenant B)
         [Parameter(Mandatory=$true, Position=6)]
         [string] $destAppId,
         [Parameter(Mandatory=$true, Position=7)]
         [string] $destStringPwd,
         [Parameter(Mandatory=$true, Position=8)]
         [string] $destinationTenantId,
         [Parameter(Mandatory=$true, Position=9)]
         [string] $destinationSubscriptionId,
         [Parameter(Mandatory=$true, Position=10)]
         [string] $destinationVmResourceGroup,
         [Parameter(Mandatory=$true, Position=11)]
         [string] $destinationStorageAccountName,
         [Parameter(Mandatory=$true, Position=12)]
         [string] $destinationStorageAccountKey,
         [Parameter(Mandatory=$true, Position=13)]
         [string] $destinationStorageAccountContainer,
         [Parameter(Mandatory=$true, Position=14)]
         [string] $destVnetName,
         [Parameter(Mandatory=$true, Position=15)]
         [string] $destSubnetName,
         [Parameter(Mandatory=$true, Position=16)]
         [string] $destinationVmLocation,
         [Parameter(Mandatory=$true, Position=17)]
         [string] $destinationVmStorageType = 'Premium_LRS'

    )

# ========================================================================================
# Author: Saurabh Rai
# Date: 29/03/2022
# Email: sarai@microsoft.com
# Version: 1.0
# Description: This script accepts the relevant inputs and migrates a virtual machine from 
# one tenant subscription to another tenant subscription.
# ========================================================================================


#STEPS:
#======
#
#1) Ensure that the Source VM is Stopped.
#2) Get all the disks of the VM under consideration.
#3) Generate downloadable url for VHD of each disk.
#4) Download each VHD in destination storage account.
#5) Use the VHDs to create the Disks in the destination subscription.
#6) Create VM out of the created Disks
#7) VM Migrated to another Tenant. Hurray!!

'''
# Sample Command line call with Arguements

.\VMMigrationT2T.ps1 `
-sourceAppId "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXX" `
-sourceStringPwd "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXX" `
-sourceTenantId "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXX" `
-sourceSubscriptionId "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXX" `
-sourceVmName "SrcWin2019Vm" `
-sourceVmResourceGroup "vm_migration_source_rg" `
-destAppId "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXX" `
-destStringPwd "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXX" `
-destinationTenantId "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXX" `
-destinationSubscriptionId "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXX" `
-destinationVmResourceGroup "vm_migration_destination_rg" `
-destinationStorageAccountName “vmmigrationdestinationsa” `
-destinationStorageAccountKey "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXX" `
-destinationStorageAccountContainer “vmmigrationdestinationcontainer” `
-destVnetName "dest-vnet" `
-destSubnetName "dest-subnet" `
-destinationVmLocation "westus" `
-destinationVmStorageType "Premium_LRS"

'''

# ========================================================================================
# SOURCE TENANT OPERATIONS
#
# Copy the VM snapshot (*.VHD file) from the source tenant to a storage account in the destination tenant.
# ========================================================================================

# Turn off the Source VM
Stop-AzVM -ResourceGroupName $sourceVmResourceGroup -Name $sourceVmName -Force
Write-Host "Src VM Stopped"

$sourceSecureStringPwd = $sourceStringPwd | ConvertTo-SecureString -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sourceAppId, $sourceSecureStringPwd
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $sourceTenantId -SubscriptionId $sourceSubscriptionId
Write-Host "Logged In to Src Sub"

$sourceVm = Get-AzVM -ResourceGroupName $sourceVmResourceGroup -Name $sourceVmName

# Get disk names attached to the VM
$diskList = New-Object System.Collections.Generic.List[System.Object]
$diskList.Add($sourceVm.StorageProfile.OsDisk.Name)
foreach($datadisk in $sourceVm.StorageProfile.DataDisks)
{
    $diskList.Add($datadisk.Name)
}

# Get the actual disks
$sourceVmDisks = Get-AzDisk -ResourceGroupName $sourceVmResourceGroup -DiskName $disk.Name | Where-Object -Property Name -In $diskList
Write-Host "Extracted the Src VM Disks"

Write-Host "Push VHDs started"
$sasList = New-Object System.Collections.Generic.List[System.Object]
# Export the VHD of each disk to destination storage account in another tenant
foreach($srcDisk in $sourceVmDisks)
{

$sas = Grant-AzDiskAccess -ResourceGroupName $sourceVmResourceGroup -DiskName $srcDisk.Name -DurationInSecond 3600 -Access Read
$destContext = New-AzStorageContext –StorageAccountName $destinationStorageAccountName -StorageAccountKey $destinationStorageAccountKey
Start-AzStorageBlobCopy -AbsoluteUri $sas.AccessSAS -DestContainer $destinationStorageAccountContainer -DestContext $destContext -DestBlob $srcDisk.Name
$sasList.Add($sas)

# Waiting for the copy to complete. This is sequential for PoC. Will make it parallel later.
    while($true)
    {
        $copyStatus = Get-AzStorageBlobCopyState -Blob $srcDisk.Name -Container $destinationStorageAccountContainer -Context $destContext
        if($copyStatus.Status -eq "Success")
        {
            break;
        }
        else
        {
            Start-Sleep -Seconds 5
        }

    }

}
Write-Host "Push VHDs Ended"

# ========================================================================================
# DESTINATION TENANT OPERATIONS
# Create disks out of the VHDs
# Create a new VM and attach these disks to the VM.
# ========================================================================================

$destSecureStringPwd = $destStringPwd | ConvertTo-SecureString -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $destAppId, $destSecureStringPwd
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $destinationTenantId -Subscription $destinationSubscriptionId
Write-Host "Logged In to Dest Sub"

$destinationVhdStorageAccountResourceId = (Get-AzStorageAccount -ResourceGroupName $destinationVmResourceGroup -AccountName $destinationStorageAccountName).Id

foreach($disk in $sourceVmDisks)
{
    $diskName = $disk.Name
    $vhdUri = "https://$destinationStorageAccountName.blob.core.windows.net/$destinationStorageAccountContainer/$diskName"
    if(($disk.OsType -eq "Windows") -or ($disk.OsType -eq "Linux")) # It is OS disk
    {
        $diskConfig = New-AzDiskConfig -AccountType $destinationVmStorageType -Location $destinationVmLocation -CreateOption Import -StorageAccountId $destinationVhdStorageAccountResourceId -SourceUri $vhdUri -OsType  $disk.OsType -DiskSizeGB $disk.DiskSizeGB
    }
    else
    {
        $diskConfig = New-AzDiskConfig -AccountType $destinationVmStorageType -Location $destinationVmLocation -CreateOption Import -StorageAccountId $destinationVhdStorageAccountResourceId -SourceUri $vhdUri -DiskSizeGB $disk.DiskSizeGB
    }
    New-AzDisk -Disk $diskConfig -ResourceGroupName $destinationVmResourceGroup -DiskName $diskName

}

# Create New destination VM and mount the disks.

$destVnet = Get-AzVirtualNetwork -Name $destVnetName -ResourceGroupName $destinationVmResourceGroup
$destSubnet = Get-AzVirtualNetworkSubnetConfig -Name $destSubnetName -VirtualNetwork $destVnet

$destNicName = (($sourceVm.NetworkProfile.NetworkInterfaces[0].Id) -split '/')[-1]
$destNic = New-AzNetworkInterface -Name $destNicName -ResourceGroupName $destinationVmResourceGroup -Location $destinationVmLocation -SubnetId $destSubnet.Id

$destVmConfig = New-AzVMConfig -VMName $sourceVm.Name -VMSize $sourceVm.HardwareProfile.VmSize
$destVm = Add-AzVMNetworkInterface -VM $destVmConfig -Id $destNic.Id


$destVmDisks = Get-AzDisk -Name $sourceVmName* -ResourceGroupName $destinationVmResourceGroup

foreach($disk in $destVmDisks)
{
    $LunNumber = 0
    if($disk.OsType -eq "Windows") # It is Windows OS disk
    {
        $destVm = Set-AzVMOSDisk -VM $destVm -ManagedDiskId $disk.Id -StorageAccountType $destinationVmStorageType -DiskSizeInGB $disk.DiskSizeGB -CreateOption Attach -Windows
    }
    elseif($disk.OsType -eq "Linux") # It is Linux OS disk
    {
        $destVm = Set-AzVMOSDisk -VM $destVm -ManagedDiskId $disk.Id -StorageAccountType $destinationVmStorageType -DiskSizeInGB $disk.DiskSizeGB -CreateOption Attach -Linux
    }
    else
    {
        $destVm = Add-AzVMDataDisk -CreateOption Attach -Lun $LunNumber -VM $destVm -ManagedDiskId $disk.Id
        $LunNumber = $LunNumber + 1
    }

}

Write-Host "Dest VM creation started"

# Finally create the VM in the background
New-AzVM -ResourceGroupName $destinationVmResourceGroup -Location $destinationVmLocation -VM $destVm -AsJob

Write-Host "Dest VM creation Ended"

'''
# Release the Source Disks from Export Wizard and Turn on the Source VM

# Change context to Source Subscription First

$pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sourceAppId, $sourceSecureStringPwd
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $sourceTenantId -SubscriptionId $sourceSubscriptionId

foreach($sas in $sasList)
{
    Remove-AzDiskAccess -ResourceGroupName $sourceVmResourceGroup -Name $sas.AccessSAS
}

# Turn on the Source VM
Start-AzVM -ResourceGroupName $sourceVmResourceGroup -Name $sourceVmName
'''





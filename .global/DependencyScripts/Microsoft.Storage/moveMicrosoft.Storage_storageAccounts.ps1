# Pre-requisite: Please install the Azure CLI using - https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli
# Access Reqiurments: A contribute access is required to both the source and target storage account. Along with a get access policy on the source and a set access policy on the target keyvault.
#  Description: With this approach, we're simplifying fetching all data from source storage account in Subscription1, 
#  and saving them to target storage account in Subscription2. 
#  Mandatory Parameters are the - source/origin storage account name and subscription guid, - target/destination 
#  storage account name and subscription guid
# Here's how you call the script:
# .\moveMicrosoft.Storage_storageAccounts.ps1 -branchName ${{ parameters.branchName }}
Param(
    [parameter(mandatory)] [string] $branchName
)
$originStorageAccount = ""
$originSubscriptionId = ""
$destinationStorageAccount = ""
$destinationSubscriptionId = ""
$originRG = ""
$destinationRG= ""
$executeScript = $true
function moveMicrosoft.Storage_storageAccounts {
    Param(
    [parameter(mandatory)] [string] $originStorageAccount,
    [parameter(mandatory)] [string] $originSubscriptionId,
    [parameter(mandatory)] [string] $destinationStorageAccount,
    [parameter(mandatory)] [string] $destinationSubscriptionId,
    [parameter(mandatory)] [string] $originRG,
    [parameter(mandatory)] [string] $destinationRG,
    [parameter(mandatory)] [string] $branchName
)
try {
       # 1. Set the source subscription id. 
       Write-Host "Setting origin subscription to: $($originSubscriptionId)..."
       az account set -s $originSubscriptionId
       
       # Get a storage account key
       $sourceStorageAccountKey= (Get-AzStorageAccountKey -ResourceGroupName $originRG -AccountName $originStorageAccount)| Where-Object {$_.KeyName -eq "key1"} 
       $targetStorageAccountKey= (Get-AzStorageAccountKey -ResourceGroupName $destinationRG -AccountName $destinationStorageAccount)| Where-Object {$_.KeyName -eq "key1"}
       
       # Get a storage account context
       $sourceStorageContext = New-AzStorageContext -StorageAccountName $originStorageAccount -StorageAccountKey $sourceStorageAccountKey.Value  
       $targetStorageContext = New-AzStorageContext -StorageAccountName $destinationStorageAccount -StorageAccountKey $targetStorageAccountKey.Value
       
       # Get a sas token for storage account
       $sourceStoragesas = New-AzStorageAccountSASToken -Context $sourceStorageContext -Service Blob,File,Table,Queue -ResourceType Service,Container,Object -Permission "rl" -ExpiryTime (Get-Date).AddDays(1) 
       $targetStoragesas = New-AzStorageAccountSASToken -Context $targetStorageContext -Service Blob,File,Table,Queue -ResourceType Service,Container,Object -Permission "rlwpa" -ExpiryTime (Get-Date).AddDays(1)
       
       # Get containers
       $containers =  Get-AzStorageContainer -Context $sourceStorageContext
       
       # Get File share
       $fileShare= Get-AzStorageShare -Context $sourceStorageContext
       
       if(![string]::IsNullOrEmpty($containers)){
       Copy-AzureStorageBlob $sourceStoragesas $targetStoragesas
       }
       
       else {
           Write-Host "Storage Account not contain container"
       }
       
       if(![string]::IsNullOrEmpty($fileShare)){
       Copy-AzureStorageFile $sourceStoragesas $targetStoragesas
       }
       else {
               Write-Host "Storage Account not contain File share"
       } 
        
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
function Copy-AzureStorageFile {
    param
    (
        [parameter(Mandatory=$true)] [String] $sourceStoragesas,
        [parameter(Mandatory=$true)] [String] $targetStoragesas
    )
    azcopy copy "https://$originStorageAccount.file.core.windows.net/$sourceStoragesas" "https://$destinationStorageAccount.file.core.windows.net/$targetStoragesas" --recursive 
}
function Copy-AzureStorageBlob {
    param
    (
        [parameter(Mandatory=$true)] [String] $sourceStoragesas,
        [parameter(Mandatory=$true)] [String] $targetStoragesas
    )
    azcopy copy "https://$originStorageAccount.blob.core.windows.net/$sourceStoragesas" "https://$destinationStorageAccount.blob.core.windows.net/$targetStoragesas" --recursive
    
}
if($executeScript -eq $true)
{
moveMicrosoft.Storage_storageAccounts -originStorageAccount $originStorageAccount -originSubscriptionId $originSubscriptionId -destinationStorageAccount $destinationStorageAccount -destinationSubscriptionId $destinationSubscriptionId -originRG $originRG -destinationRG $destinationRG -branchName $branchName
}

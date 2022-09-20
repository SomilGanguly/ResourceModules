# Pre-requisite: Please install the Azure Powershell Az Modules and Powershell for windows using - https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-5.1, https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-8.0.0

# Access Reqiurments: A contributor access is required to both the source and target Automation Account.

#  Description: With this approach, we're moving the runbooks and DSC configurations from Source to Target Automation Account.
#  Mandatory Parameters are the -  SubscriptionId, dscConfig, runbooks and branchName

# Here's how you call the script:
# .\moveMicrosoft.Automation_automationAccounts.ps1 -branchName ${{ parameters.branchName }}

param
(
    [parameter(mandatory)] [string] $branchName
)

[CmdletBinding()]

$dscConfig = @(

       [pscustomobject]@{SourceAutomationAccountName='';TargetAutomationAccountName='';
       SourceResourceGroupName='';TargetResourceGroupName= '';
       SourceOutputFolder='';
       SourcePath='';
       ConfigurationName='';
       TargetAzureVMName='';TargetNodeConfigurationName='';
       TargetConfigurationMode='';TargetAzureVMResourceGroupName=''
       }

       [pscustomobject]@{SourceAutomationAccountName='';TargetAutomationAccountName='';
       SourceResourceGroupName='';TargetResourceGroupName= '';
       SourceOutputFolder='';
       SourcePath='';
       ConfigurationName='';
       TargetAzureVMName='';TargetNodeConfigurationName='';
       TargetConfigurationMode='';TargetAzureVMResourceGroupName=''
       }
   )

   $runbooks = @(
         
       [pscustomobject]@{SourceResourceGroupName='';TargetResourceGroupName='';
       SourceAutomationAccountName='';TargetAutomationAccountName='';
       RunbookName='';OutputFolderPath='';
       SourcePath=''
       }

       [pscustomobject]@{SourceResourceGroupName='';TargetResourceGroupName='';
       SourceAutomationAccountName='';TargetAutomationAccountName='';
       RunbookName='';OutputFolderPath='';
       SourcePath=''
       }
    )

$SubscriptionId = 'f93991c1-e157-424f-b60d-6d7ce7e0f05c'
$executeScript = $true

function moveMicrosoft.Automation_automationAccounts{
    param (
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$dscConfig,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$runbooks,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,
    [parameter(mandatory)] [string] $branchName
    )  
}

try{
# 1. Set the subscription id.
Write-Host "Setting subscription to: $($SubscriptionId)..."
Select-AzSubscription -SubscriptionId "$SubscriptionId"

# 2. Moving the runbooks and DSC configurations from Source to Target Automation Account.

foreach ($eachLine in $dscConfig){
    
    Export-AzAutomationDscConfiguration `
   -Name $eachLine.ConfigurationName `
   -OutputFolder $eachLine.SourceOutputFolder `
   -ResourceGroupName $eachLine.SourceResourceGroupName `
   -AutomationAccountName $eachLine.SourceAutomationAccountName `
   -Force;

   Import-AzAutomationDscConfiguration `
   -SourcePath $eachLine.SourcePath `
   -ResourceGroupName $eachLine.TargetResourceGroupName `
   -AutomationAccountName $eachLine.TargetAutomationAccountName `
   -Published `
   -Force;
   
   Start-AzAutomationDscCompilationJob `
   -ResourceGroupName $eachLine.TargetResourceGroupName `
   -ConfigurationName $eachLine.ConfigurationName `
   -AutomationAccountName $eachLine.TargetAutomationAccountName;

   Register-AzAutomationDscNode `
   -AutomationAccountName $eachLine.TargetAutomationAccountName `
   -AzureVMName $eachLine.TargetAzureVMName `
   -ResourceGroupName $eachLine.TargetResourceGroupName `
   -NodeConfigurationName $eachLine.TargetNodeConfigurationName `
   -ConfigurationMode $eachLine.TargetConfigurationMode `
   -AzureVMResourceGroup $eachLine.TargetAzureVMResourceGroupName
}

foreach ($eachLine in $runbooks){
    Export-AzAutomationRunbook `
    -ResourceGroupName $eachLine.SourceResourceGroupName `
    -AutomationAccountName $eachLine.SourceAutomationAccountName `
    -Name $eachLine.RunbookName `
    -Slot Published `
    -OutputFolder $eachLine.OutputFolderPath `
    -Force;

    Import-AzAutomationRunbook `
    -AutomationAccountName $eachLine.TargetAutomationAccountName `
    -Name $eachLine.RunbookName `
    -Path $eachLine.SourcePath `
    -Published `
    -ResourceGroupName $eachLine.TargetResourceGroupName `
    -Type PowerShell `
    -Force;
    
    Start-AzAutomationRunbook `
    -AutomationAccountName $eachLine.TargetAutomationAccountName `
    -Name $eachLine.RunbookName `
    -ResourceGroupName $eachLine.TargetResourceGroupName
}
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

if($executeScript -eq $false)
{
    moveMicrosoft.Automation_automationAccounts -dscConfig $dscConfig -runbooks $runbooks -SubscriptionId $SubscriptionId -branchName $branchName
}
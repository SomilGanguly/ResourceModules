##
## This script is used to introduce idempotency in the Automation
## foundation framework. The script checks the Provisioned state of 
## the resource in the settings.json file and adds the push job to the 
## push pipeline for it only if the state is null or false. This ensures 
## that the push pipeline runs again from the point it failed last.
##

function Get-DeploymentStateUpdate {
    param (
    [PSCustomObject]
    $branchName,
    [string]
    $location
)
$statePath = $pwd
$resourcetype=Split-Path -path (Split-Path -path (Split-Path -Path $location -Parent) -Parent) -Leaf
$ResourceGroupName=Split-Path -path (Split-Path -path (Split-Path -path (Split-Path -Path $location -Parent) -Parent) -Parent) -Leaf
$SubscriptionName=Split-Path -path (Split-Path -path (Split-Path -path (Split-Path -path (Split-Path -Path $location -Parent) -Parent) -Parent) -Parent) -Leaf
$settinglocation=(Get-ChildItem -Path "$statePath/src/").Name
foreach($locationfile in $settinglocation)
{
  if($locationfile -match "_Settings.json")
  {
    $inputJson=Get-Content -Path "$statePath/src/$locationfile"   | ConvertFrom-Json 
    $jsonsort = $inputJson.RelocationSettings.DeploymentSequence | Sort-Object Sequence
    foreach($property in $jsonsort)
    {
      if($property.Sequence -ne $null)
      {
        if(($property.ResourceGroupName -eq $ResourceGroupName) -and ($property.SubscriptionName -eq $SubscriptionName) -and ($property.ResourceAPI_Name -eq  $resourcetype))
        {
          $property.ProvisioningState="Failed"
          $failedSequenceNumber=$property.Sequence
        }
      }
    }
    $jsonsortupdated = $inputJson.RelocationSettings.DeploymentSequence | Sort-Object Sequence
    foreach($propertyupdated in $jsonsortupdated)
    {
      if($propertyupdated.Sequence -ne $null)
      {
        if($propertyupdated.Sequence -lt $failedSequenceNumber)
        {
          $propertyupdated.ProvisioningState="Success"
        }
      }
    }
    $inputJson | ConvertTo-Json -depth 100 | set-content "$statePath/src/$locationfile"
    $inputJson | ConvertTo-Json -depth 100
          Write-Verbose "Setting git config...." -Verbose 

          git config --global user.email "azuredevops@microsoft.com"
          git config --global user.name "Azure DevOps"             

          git branch

          Write-Verbose "CHECK GIT STATUS..." -Verbose 
          git status

          Write-Verbose "git checkout...." -Verbose 
          git checkout -b $branchName

          Write-Verbose "git pull...." -Verbose 
          git pull origin $branchName

          Write-Verbose "GIT ADD..." -Verbose 
          git add "$statePath/src/$locationfile"

          Write-Verbose "Commiting the changes..." -Verbose 
          git commit -m "Update from Build"

          Write-Verbose "Pushing the changes..." -Verbose 
          git push origin $branchName

          Write-Verbose "CHECK GIT STATUS..." -Verbose 
          git status
  }
}
}
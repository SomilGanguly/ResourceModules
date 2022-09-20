function Create-PushPipeline {
        param (
        [PSCustomObject]
        $SubscriptionId,
        [string]
        $statePath = $pwd
    )
## Initializing variables for context
$subscriptionObject = Get-AzSubscription -SubscriptionId $SubscriptionId
$subscriptionName= $subscriptionObject.Name
$settinglocation=(Get-ChildItem -Path "$statePath/src/").Name
foreach($locationfile in $settinglocation)
{
if($locationfile -match "_Settings.json")
{
$inputJson=Get-Content -Path "$statePath/src/$locationfile" 
$WorkloadNameFlag=($inputJson | ConvertFrom-Json).RelocationSettings.WorkloadName
## Initializing pipeline variables
$pSourceBranchName='$(Build.SourceBranchName)'
$pBranchName='$(branch)'
##
## Curating push pipeline.
## This section of the script helps in populating the push pipeline with jobs to deploy the resources in the sequence
## that has been declared through sequence numbers in the settings.json file in src directory.
##

$yamledit = @"
trigger: none
variables:
  - name: branch
    value: $pSourceBranchName

stages:
################################DO NOT DELETE THIS LINE################################################################

"@
$yamledit | Out-File -FilePath "$statePath/.global/Pipelines/RelocationPush.yml"         
          $inputJson=Get-Content -Path "$statePath/src/$locationfile"   | ConvertFrom-Json # "$statePath/src/Settings.json"
          $jsonarray=  @()
          $jsonsort = $inputJson.RelocationSettings.DeploymentSequence | Sort-Object Sequence
          foreach($property in $jsonsort){
          if($property.Sequence -ne $null -and ($property.ProvisioningState -ne "Success")){
          $name=($property).ResourceAPI_Name
          $RG=($property).ResourceGroupName
          ## Replacing '.' and '-' with '_' since stagenames cannot contain periods(.) and hyphen (-)
          $stageName=($RG + '_' + $name).Replace('.', '_').Replace('-','_').Replace(' ','_')
          if($dependcyName){
             $pdependon="  dependsOn: $dependcyName"
             $Pcondition="  condition: in(dependencies.$dependcyName.result, 'Succeeded')"
             $pdependentjobcondition="  condition: in(dependencies.$stageName.result, 'Failed')"

          }
          else{

            $pdependon=''
            $Pcondition="  condition: succeededOrFailed()"
            $pdependentjobcondition="  condition: Failed()"
          }
$yaml = @"
- stage: $stageName
$pdependon
$Pcondition
  jobs:
  - template: "/$WorkloadNameFlag/$subscriptionName/$RG/$name/pipelines/$name.yml"
- stage: "DeploymentStateUpdate_$stageName"
$pdependentjobcondition
  jobs:
  - job: "DeploymentStateUpdate_$stageName"
    steps:
    - checkout: self
      clean: true
      persistCredentials: true
    - powershell: |
          Import-Module .\src\internal\functions\Get-DeploymentStateUpdate.ps1 -Force
          Get-DeploymentStateUpdate -branchName $pBranchName -location "/$WorkloadNameFlag/$subscriptionName/$RG/$name/pipelines/$name.yml"
      displayName: 'DeploymentStateUpdate'
"@
$dependcyName=($RG + '_' + $name).Replace('.', '_').Replace('-','_').Replace(' ','_')
$jsonarray+=$yaml
          } 
          }
          $jsonarray | Out-File -FilePath "$statePath/.global/Pipelines/RelocationPush.yml" -Append
          }
          }
} 
##
## This file is used to curate yaml child pipelines for each resource.
##
function Curated-YmlFile {
        param (
        [PSCustomObject]
        $SubscriptionId,
        [string]
        $statePath = $pwd,
        [string]
        $serviceConnection,
        [string]
        $branchName
    )
    
$subscriptionObject = Get-AzSubscription -SubscriptionId $SubscriptionId
$templateFunctionsPath='.global/Pipelines/Scripts'
$vmImage='ubuntu-latest'
$settinglocation=(Get-ChildItem -Path "$statePath/src/").Name
foreach($locationfile in $settinglocation)
{
  if($locationfile -match "_Settings.json")
  {
    $settingfile=get-content -path "$statePath/src/$locationfile"
    $RelocationSettings=($settingfile | ConvertFrom-Json).RelocationSettings.TargetLocation
    $WorkloadNameFlag=($settingfile | ConvertFrom-Json).RelocationSettings.WorkloadName 
  }
}
$subscriptionName= $subscriptionObject.Name
$basePath= Join-Path -Path "$statePath/$WorkloadNameFlag" -ChildPath $subscriptionName
$basefolder=(Get-ChildItem -Path $basePath  -Directory).Name
foreach($folder in $basefolder)
{
$level1folder=(get-childitem -path (Join-Path -Path $basePath -ChildPath $folder) -Directory).Name
$level1folderfullpath=Join-Path -Path $basePath -ChildPath $folder
foreach($eachL1folder in $level1folder)
{
    $level2folderfullpath=Join-Path -Path $level1folderfullpath -ChildPath $eachL1folder
    $deployfilename=(Get-ChildItem -Path $level2folderfullpath -File).Name.replace('.deploy.json','')
    if($deployfilename.count -ne 1)
    {
      $deployFileModified=Create-YmlFileObject -array $deployfilename -objectname "deployFile"
    }
    else{
$ymlcreateobjdeploy= @"
- name: deployFile
  type: object
  default:
  - $deployfilename
"@
        $deployFileModified=$ymlcreateobjdeploy
    }
    $paramFolderFilter=(Get-ChildItem -Path $level2folderfullpath -Directory | where{$_.Name -eq 'parameters'}).Name
    $ParamFileName=(Get-ChildItem -Path (Join-Path -Path $level2folderfullpath -ChildPath $paramFolderFilter) -File).Name.replace('.parameters.json','')
    if($ParamFileName.count -ne 1){
    
    $ParamFileModified=Create-YmlFileObject -array $ParamFileName -objectname "parameterFileName"
    }
    ## multiple instance case
    else{
$ymlcreateobjParam= @"
- name: parameterFileName
  type: object
  default:
  - $ParamFileName
"@
        $ParamFileModified=$ymlcreateobjParam
    }
    $pipelineFolderFilter=(Get-ChildItem -Path $level2folderfullpath -Directory | where{$_.Name -eq 'pipelines'}).Name
    $pipelineFileName=Join-Path -Path $level2folderfullpath -ChildPath $pipelineFolderFilter
    
    if((Get-ChildItem -Path $level2folderfullpath -Directory).Name -contains "scripts")
    {   
    $scriptsFileFilter=(Get-ChildItem -Path (Join-Path -Path $level2folderfullpath -ChildPath "scripts") -File).FullName    
    foreach($scriptsFile in $scriptsFileFilter)
    {
    $scriptFileModif1=$scriptsFile.Replace($statePath,'').Replace('\','/')
    $scriptFileModif2=$scriptFileModif1.Substring($scriptFileModif1.IndexOf('/')+1)
    $pdeploymentfilename1='_${{ paramdeploy }}.ps1'
    $scriptFileModif3=$scriptFileModif2.Substring(0, $scriptFileModif2.lastIndexOf('_'))
    $scriptFileModif=$scriptFileModif3+$pdeploymentfilename1
    
    $fileContent=Get-Content -Path $scriptsFile
    if($fileContent){

    $scriptLine=($fileContent | Where-Object {$_ -like ‘# .\*’}).Replace('#','')
    $arg=$scriptline.Substring($scriptline.IndexOf(' -')+1)

$pdependentjob='${{ parameters.dependentjob }}'
$pjobName='${{ parameters.jobName }}${{replace(replace(replace(paramdeploy,''-'', ''''),''.'', ''''),'' '','''')}}'
$pparametersPath='${{ parameters.parametersPath }}'
$pparameterFileName='${{ paramparameterFile }}'
$pserviceConnection='${{ parameters.serviceConnection }}'
$ptemplateFunctionsPath='${{ parameters.templateFunctionsPath }}' 
$pdeployFile='src/carml/Microsoft.Storage/storageAccounts/deploy.bicep'
$plocation='${{ parameters.location }}' 
$pmodulePath='${{ parameters.modulePath }}' 
$pmoduleName='${{ parameters.moduleName }}'
$presourceGroupName='${{ parameters.resourceGroupName }}' 
$pmodulesRepository='$(modulesRepository)' 
$pmodulesPath='$(modulesPath)'
$pconditionLogic1= '- ${{ each paramdeploy in parameters.deployFile }}:'
$pconditionLogic2= '  - ${{ each paramparameterFile in parameters.parameterFileName }}:'
$pconditionLogic3= '    - ${{ if eq(paramdeploy,paramparameterFile) }}:'
$pazurePowerShellVersion='${{ parameters.azurePowerShellVersion }}' 
$ppreferredAzurePowerShellVersion='${{ parameters.preferredAzurePowerShellVersion }}'
$psubscriptionId='${{ parameters.subscriptionId }}'

$yaml1 = @"

parameters:
$deployFileModified
- name: parametersPath
  default: '$WorkloadNameFlag/$subscriptionName/$folder/$eachL1folder/$paramFolderFilter'
- name: pipelineCustomVersion  
  default: '1.0.0'
- name: moduleRg
  default: '$folder'
- name: modulesPath  
  default: '$pmodulesPath'
- name: vmImage
  default: $vmImage
- name: moduleName  
  default: $eachL1folder
- name: location
  default: $RelocationSettings
- name: templateFunctionsPath  
  default: '$templateFunctionsPath'
- name: modulePath
  default: $WorkloadNameFlag/$subscriptionName/$folder/$eachL1folder
- name: serviceConnection
  default: $serviceConnection
- name: modulesRepository
  default: '$pmodulesRepository'
$ParamFileModified
- name: resourceGroupName
  default: ''
- name: poolName
  default: ''
- name: dependentjob
  default: 'true'
- name: jobName 
  default: 'DeploymentOfResource'
- name: branchName 
  default: $branchName
- name: azurePowerShellVersion
  default: 'latestVersion'
- name: preferredAzurePowerShellVersion
  default: ''
- name: subscriptionId
  default: '$SubscriptionId'
  

jobs:
$pconditionLogic1
$pconditionLogic2
$pconditionLogic3
      - template: /.global/Pipelines/.templates/pipeline.jobs.deploy.yml
        parameters:
          deploymentBlocks:
          - path: $pparametersPath/$pparameterFileName.parameters.json
            jobName: $pjobName
          serviceConnection: $pserviceConnection
          deployFile: $pdeployFile
          templateFunctionsPath: $ptemplateFunctionsPath
          location: $plocation
          modulePath: $pmodulePath
          moduleName: $pmoduleName
          resourceGroupName: $presourceGroupName
          azurePowerShellVersion: $pazurePowerShellVersion
          preferredAzurePowerShellVersion: $ppreferredAzurePowerShellVersion
          subscriptionId: $psubscriptionId

      - job:
        condition: and(succeeded(), eq('$pdependentjob', 'true'))
        dependsOn: $pjobName
        steps:
        - checkout: self
          clean: true
          persistCredentials: true
        - task: AzureCLI@2
          displayName: 'DependentJob'
          inputs:
            azureSubscription: $pserviceConnection
            scriptType: pscore
            scriptPath: '$scriptFileModif'
            arguments: '$arg'
"@
Write-Host "$pipelineFileName/$eachL1folder.yml"
$yaml1
$yaml1 | Out-File -FilePath "$pipelineFileName/$eachL1folder.yml"
    }   
else{

$pjobName='${{ parameters.jobName }}${{replace(replace(replace(paramdeploy,''-'', ''''),''.'', ''''),'' '','''')}}'
$pparametersPath='${{ parameters.parametersPath }}'
$pparameterFileName='${{ paramparameterFile }}'
$pserviceConnection='${{ parameters.serviceConnection }}'
$ptemplateFunctionsPath='${{ parameters.templateFunctionsPath }}' 
$pdeployFile='src/carml/Microsoft.Storage/storageAccounts/deploy.bicep'
$plocation='${{ parameters.location }}' 
$pmodulePath='${{ parameters.modulePath }}' 
$pmoduleName='${{ parameters.moduleName }}'
$presourceGroupName='${{ parameters.resourceGroupName }}' 
$pmodulesRepository='$(modulesRepository)' 
$pmodulesPath='$(modulesPath)'
$pconditionLogic1= '- ${{ each paramdeploy in parameters.deployFile }}:'
$pconditionLogic2= '  - ${{ each paramparameterFile in parameters.parameterFileName }}:'
$pconditionLogic3= '    - ${{ if eq(paramdeploy,paramparameterFile) }}:'
$pazurePowerShellVersion='${{ parameters.azurePowerShellVersion }}' 
$ppreferredAzurePowerShellVersion='${{ parameters.preferredAzurePowerShellVersion }}'
$psubscriptionId='${{ parameters.subscriptionId }}' 

$yaml = @"
parameters:
$deployFileModified
- name: parametersPath
  default: '$WorkloadNameFlag/$subscriptionName/$folder/$eachL1folder/$paramFolderFilter'
- name: pipelineCustomVersion  
  default: '1.0.0'
- name: moduleRg
  default: '$folder'
- name: modulesPath  
  default: '$pmodulesPath'
- name: vmImage
  default: $vmImage
- name: moduleName  
  default: $eachL1folder
- name: location
  default: $RelocationSettings
- name: templateFunctionsPath  
  default: '$templateFunctionsPath'
- name: modulePath
  default: $WorkloadNameFlag/$subscriptionName/$folder/$eachL1folder
- name: serviceConnection
  default: $serviceConnection
- name: modulesRepository
  default: '$pmodulesRepository'
$ParamFileModified
- name: resourceGroupName
  default: ''
- name: poolName
  default: ''
- name: jobName 
  default: 'DeploymentOfResource'
- name: azurePowerShellVersion
  default: 'latestVersion'
- name: preferredAzurePowerShellVersion
  default: ''
- name: subscriptionId
  default: '$SubscriptionId'




jobs:
$pconditionLogic1
$pconditionLogic2
$pconditionLogic3
      - template: /.global/Pipelines/.templates/pipeline.jobs.deploy.yml
        parameters:
          deploymentBlocks:
          - path: $pparametersPath/$pparameterFileName.parameters.json
            jobName: $pjobName
          serviceConnection: $pserviceConnection
          deployFile: $pdeployFile
          templateFunctionsPath: $ptemplateFunctionsPath
          location: $plocation
          modulePath: $pmodulePath
          moduleName: $pmoduleName
          resourceGroupName: $presourceGroupName
          azurePowerShellVersion: $pazurePowerShellVersion
          preferredAzurePowerShellVersion: $ppreferredAzurePowerShellVersion
          subscriptionId: $psubscriptionId


"@
Write-Host "$pipelineFileName/$eachL1folder.yml"
$yaml | Out-File -FilePath "$pipelineFileName/$eachL1folder.yml"
}
    }
    }
else{

$pjobName='${{ parameters.jobName }}${{replace(replace(replace(paramdeploy,''-'', ''''),''.'', ''''),'' '','''')}}'
$pparametersPath='${{ parameters.parametersPath }}'
$pparameterFileName='${{ paramparameterFile }}'
$pserviceConnection='${{ parameters.serviceConnection }}'
$ptemplateFunctionsPath='${{ parameters.templateFunctionsPath }}' 
$pdeployFile='src/carml/Microsoft.Storage/storageAccounts/deploy.bicep'
$plocation='${{ parameters.location }}' 
$pmodulePath='${{ parameters.modulePath }}' 
$pmoduleName='${{ parameters.moduleName }}'
$presourceGroupName='${{ parameters.resourceGroupName }}' 
$pmodulesRepository='$(modulesRepository)' 
$pmodulesPath='$(modulesPath)'
$pconditionLogic1= '- ${{ each paramdeploy in parameters.deployFile }}:'
$pconditionLogic2= '  - ${{ each paramparameterFile in parameters.parameterFileName }}:'
$pconditionLogic3= '    - ${{ if eq(paramdeploy,paramparameterFile) }}:'
$pazurePowerShellVersion='${{ parameters.azurePowerShellVersion }}' 
$ppreferredAzurePowerShellVersion='${{ parameters.preferredAzurePowerShellVersion }}'
$psubscriptionId='${{ parameters.subscriptionId }}' 

$yaml = @"
parameters:
$deployFileModified
- name: parametersPath
  default: '$WorkloadNameFlag/$subscriptionName/$folder/$eachL1folder/$paramFolderFilter'
- name: pipelineCustomVersion  
  default: '1.0.0'
- name: moduleRg
  default: '$folder'
- name: modulesPath  
  default: '$pmodulesPath'
- name: vmImage
  default: $vmImage
- name: moduleName  
  default: $eachL1folder
- name: location
  default: $RelocationSettings
- name: templateFunctionsPath  
  default: '$templateFunctionsPath'
- name: modulePath
  default: $WorkloadNameFlag/$subscriptionName/$folder/$eachL1folder
- name: serviceConnection
  default: $serviceConnection
- name: modulesRepository
  default: '$pmodulesRepository'
$ParamFileModified
- name: resourceGroupName
  default: ''
- name: poolName
  default: ''
- name: jobName 
  default: 'DeploymentOfResource'
- name: azurePowerShellVersion
  default: 'latestVersion'
- name: preferredAzurePowerShellVersion
  default: ''
- name: subscriptionId
  default: '$SubscriptionId'




jobs:
$pconditionLogic1
$pconditionLogic2
$pconditionLogic3
      - template: /.global/Pipelines/.templates/pipeline.jobs.deploy.yml
        parameters:
          deploymentBlocks:
          - path: $pparametersPath/$pparameterFileName.parameters.json
            jobName: $pjobName
          serviceConnection: $pserviceConnection
          deployFile: $pdeployFile
          templateFunctionsPath: $ptemplateFunctionsPath
          location: $plocation
          modulePath: $pmodulePath
          moduleName: $pmoduleName
          resourceGroupName: $presourceGroupName
          azurePowerShellVersion: $pazurePowerShellVersion
          preferredAzurePowerShellVersion: $ppreferredAzurePowerShellVersion
          subscriptionId: $psubscriptionId

"@
Write-Host "$pipelineFileName/$eachL1folder.yml"
$yaml | Out-File -FilePath "$pipelineFileName/$eachL1folder.yml"
}
}
}
}
$statePath = $pwd   
$settinglocation=(Get-ChildItem -Path "$statePath/src/").Name
foreach($locationfile in $settinglocation)
{
    # Fetching target location for the relocation from the configured settings
    if($locationfile -match "_Settings.json")
    {
        $settingfile=get-content -path "$statePath/src/$locationfile"
        $RelocationSettings=($settingfile | ConvertFrom-Json).RelocationSettings.TargetLocation
        $RelocationSettingsDeploymentSequence=($settingfile | ConvertFrom-Json).RelocationSettings.DeploymentSequence
        $RelocationSettingsDeploymentSequence=($settingfile | ConvertFrom-Json).RelocationSettings.DeploymentSequence | Sort-Object Sequence
    }
}
$script:Parentlocation = Split-Path -Parent $MyInvocation.MyCommand.Path -Resolve
$script:Parent = Split-Path -Parent -Path $Parentlocation
$script:Parentlevel2 = Split-Path -Parent -Path $Parent
$script:Parentlevel3 = Split-Path -Parent -Path $Parentlevel2
# Storing directory/folder names of the Workload,Subscription, Resource groups and Modules formed after running Relocation pull pipeline
$script:workloadfolder = (Get-ChildItem -Path $Parentlevel3 -Directory -Exclude ".global","src","Modules").FullName
$script:subscriptionFolder = (Get-ChildItem -Path $workloadfolder -Directory).FullName
$script:ResourceGroupFolder = (Get-ChildItem -Path $subscriptionFolder -Directory).FullName
$script:moduleFolderPaths = (Get-ChildItem -Path $ResourceGroupFolder -Directory).FullName

foreach($property in $RelocationSettingsDeploymentSequence)
{
    if($property.Sequence -ne $null)
    {
        foreach($mFolderPath in $moduleFolderPaths)
        {
            $mFolderPathmod1=$mFolderPath.Substring(0,$mFolderPath.LastIndexOf('/')+0)
            $mFolderPathmod2=$mFolderPathmod1.Substring($mFolderPathmod1.LastIndexOf('/')+1)
            $api_name= Split-Path -Path $mFolderPath -Leaf
            $deployFile=Get-ChildItem -Path $mFolderPath -File
            $paramFile=Get-ChildItem -Path "$mFolderPath/parameters" -File
            $validationArtifactFile=Get-ChildItem -Path "$mFolderPath/validationartifacts" -File
            foreach($dFile in $deployFile)
            {
                $templateFileName=$dFile.Name.replace('.deploy.json','')
                foreach($pFile in $paramFile)
                {
                    $templateParamFileName=$pFile.Name.replace('.parameters.json','')
                    foreach($validationArtifact in $validationArtifactFile)
                    {
                        $validationArtifactFileName=$validationArtifact.Name.replace('.validation.txt','')
                        if(($templateFileName -eq $templateParamFileName) -and ($templateFileName -eq $validationArtifactFileName))
                        {
                            if(($property.ResourceGroupName -eq $mFolderPathmod2) -and ($property.ResourceAPI_Name -eq $api_name))
                            {
                                $deploymentSchema = (ConvertFrom-Json (Get-Content -Raw -Path "$mFolderPath/$templateFileName.deploy.json")).'$schema'
                                switch -regex ($deploymentSchema)
                                {
                                    '\/deploymentTemplate.json#$' {

                                    $ymlFileName=(Get-ChildItem -Path "$mFolderPath/pipelines").FullName
                                    $mod=(ConvertFrom-Yaml (Get-Content -Raw -Path $ymlFileName)).parameters.Values
                                    $Matches = $mod | Select-String -Pattern "resourceGroupName" -Context 1
                                    $updatedRgNamePost=$Matches.Context.PostContext
                                    $updatedRgNamePre=$Matches.Context.PreContext
                                        if($updatedRgNamePost[0])
                                        {
                                        $rgName=$updatedRgNamePost[0]
                                        }
                                        else
                                        {
                                        $rgName=$updatedRgNamePre[0]
                                        }
                                    $rgName
                                    $whatifresult=Get-AzResourceGroupDeploymentWhatIfResult -Name "Test" -ResourceGroupName $rgName -Mode Incremental -TemplateParameterFile "$mFolderPath/parameters/$templateParamFileName.parameters.json" -TemplateFile "$mFolderPath/$templateFileName.deploy.json" *>&1
                                    $whatifresult | Tee-Object -FilePath "$mFolderPath/validationartifacts/$validationArtifactFileName.validation.txt" -Append
                                    }
                                    '\/subscriptionDeploymentTemplate.json#$' {

                                    $whatifresult=Get-AzSubscriptionDeploymentWhatIfResult -Name "Test" -Location $RelocationSettings -TemplateParameterFile "$mFolderPath/parameters/$templateParamFileName.parameters.json" -TemplateFile "$mFolderPath/$templateFileName.deploy.json" *>&1
                                    $whatifresult | Tee-Object -FilePath "$mFolderPath/validationartifacts/$validationArtifactFileName.validation.txt" -Append
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

##
## This script is called in the relocation pull yaml file. 
## It is being used to copy the additional scripts and dependency scripts 
## from the global directory in main branch to a scripts folder for specific
## service in the relocationpull_n branch.
##
function Dependencycopy {
    # Discover RG, Resources
    [CmdletBinding()]
    param (
        [PSCustomObject]
        $SubscriptionId,
        [string]
        $statePath = $pwd
    )
    $inputJson=Get-Content -Path "$statePath/src/Settings.json"  
    $WorkloadNameFlag=($inputJson | ConvertFrom-Json).RelocationSettings.WorkloadName
    $subscriptionObject = Get-AzSubscription -SubscriptionId $SubscriptionId   
    $subscriptionPath = (Join-Path -Path "$statePath/$WorkloadNameFlag" -ChildPath $subscriptionObject.Name)
    $globalFolderItem=(Get-ChildItem -Path "$statePath/.global/DependencyScripts").Name
    foreach($globalItem in $globalFolderItem)
    {
        $subscriptionFolderItem=(Get-ChildItem -Path $subscriptionPath).Name
        foreach($Folderitem in $subscriptionFolderItem)
        {
            $resourceTypeFolder=(Get-ChildItem -Path $subscriptionPath/$Folderitem).Name
            foreach($folder in $resourceTypeFolder)
            {   
                $pipelinetargetfolder=(Join-Path -Path "$subscriptionPath/$Folderitem/$folder" -ChildPath "pipelines" -ErrorAction SilentlyContinue)
                $pipelinetargetfoldername=(Get-ChildItem -Path $pipelinetargetfolder -ErrorAction SilentlyContinue).Name
                $pipelinetargetcompletepath=(Join-Path -Path $pipelinetargetfolder -ChildPath $pipelinetargetfoldername -ErrorAction SilentlyContinue)
                $sourcePipeline= "$statePath/.global/Pipelines/.templates/resource.yml"
                Get-Content -Path $sourcePipeline | Out-File $pipelinetargetcompletepath -ErrorAction SilentlyContinue

                
                $curatedname=$folder.Substring(0, $folder.IndexOf('_'))
                if($globalItem -eq $curatedname)
                {
                    $targetfile=(Get-ChildItem -Path "$subscriptionPath/$Folderitem/$folder/scripts").Name
                    $outputFile= Join-Path -Path "$subscriptionPath/$Folderitem/$folder" -ChildPath "scripts/$targetfile"
                    $copyFileName=(Get-ChildItem -Path "$statePath/.global/DependencyScripts/$globalItem").Name
                    $copyFileCompletePath=(Join-Path -Path "$statePath/.global/DependencyScripts/$globalItem" -ChildPath $copyFileName)
                    Get-Content -Path $copyFileCompletePath | Out-File $outputFile
                   
                }

            } 
        }
    }
}


    
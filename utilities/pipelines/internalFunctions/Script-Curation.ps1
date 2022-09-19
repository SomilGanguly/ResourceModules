##
## This script is called in the relocation pull yaml file. 
## It is being used to change the names of the additional scripts 
## and dependency scripts to include the names of the resource 
## in the scripts in the relocationpull_n branch. 
##

function Script-Curation {
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
    $resourceGroupFolder=(Get-ChildItem -Path $subscriptionPath).Name
    foreach($rgFolder in $resourceGroupFolder)
    {
        $resourcefolder=Get-ChildItem -Path $subscriptionPath/$rgFolder -Directory
        $resources=($resourcefolder).Name
        foreach($resource in $resources)
        {
            $scriptfullpath=Join-Path -Path "$subscriptionPath/$rgFolder/$resource" -ChildPath "scripts"      
            if(Test-path -Path $scriptfullpath)
            {
                $scripts=Get-ChildItem -Path $scriptfullpath   
                foreach($script in $scripts)
                {
                    $deployfile=Get-ChildItem -Path "$subscriptionPath/$rgFolder/$resource" -File
                    foreach($file in $deployfile)
                    {
                        ## Deriving name of the resource from the deploy.json file pulled.
                        $deployfilename=$file.Name.replace('.deploy.json','')
                        $newfile=$script.Name.Replace('.ps1','')+'_'+$deployfilename+'.ps1'
                        $testnewpath=Test-Path -Path "$scriptfullpath/$newfile"
                        if($testnewpath -eq $False)
                        {       
                            $DirectoryName=$script.DirectoryName         
                            Copy-Item -Path $script.FullName -Destination $DirectoryName/$newfile
                        }
                    }
                Remove-Item -Path $script.FullName        
                }
            }
        }   
    }
}
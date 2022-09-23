
function Update-FolderStructureInJson{
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
$subscriptionPath = "$statePath/$WorkloadNameFlag"
$baseDirectory=(Get-ChildItem -Path $subscriptionPath -Directory).Name
$obj = $inputJson| ConvertFrom-Json
foreach($eachBasedirectory in $baseDirectory)
{
    if($eachBasedirectory -eq $subscriptionObject.Name)
    {
        $leve0=(Get-ChildItem -Path (Join-Path -Path $subscriptionPath -ChildPath $eachBasedirectory) -Recurse -Directory -Depth 0).Name
        foreach($folder in $leve0)
        {
            $resourcesFolder=(Get-ChildItem -Path (Join-Path -Path $subscriptionPath -ChildPath $eachBasedirectory/$folder) -Recurse -Directory -Depth 0).Name
            foreach($eachRsFolder in $resourcesFolder)
            {
                $json=@()
                $info= "" | select SubscriptionName,ResourceGroupName,ResourceAPI_Name,Sequence,ProvisioningState
                $info.SubscriptionName = $eachBasedirectory
                $info.ResourceGroupName = $folder
                $info.ResourceAPI_Name = $eachRsFolder
                $json+=$info
                $obj.RelocationSettings.DeploymentSequence += $json
                $obj | ConvertTo-Json -Depth 100 | jq '.'  | Out-File -FilePath "$statePath/src/Settings.json"
            }
        }
    }
}
}
    
    
    
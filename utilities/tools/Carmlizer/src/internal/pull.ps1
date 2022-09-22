function Get-CARMLPull {

    [CmdletBinding()]
    param (
        [string]
        $SubscriptionId,

        [string]
        $statePath = $pwd
    )
    
    # Context Check Try-catch generalize the exception
    $allAzContext = Get-AzContext -ListAvailable
    if($allAzContext.Subscription.Id -contains $SubscriptionId)
    {
        Write-Host "The context has permission on the subscription"
        Select-AzSubscription -SubscriptionId $SubscriptionId

    }
    else{
        Write-Host "The context doesnot permission on the subscription"
        exit
    }

    # Create Root folder for Subscription
    $subscriptionObject = Get-AzSubscription -SubscriptionId $SubscriptionId
    $settingfile=get-content -path "$statePath/src/Settings.json"  
    $WorkloadNameFlag=($settingfile | ConvertFrom-Json).RelocationSettings.WorkloadName
    $WorkloadPath = (Join-Path -Path $statePath -ChildPath $WorkloadNameFlag)
    if(!(Test-Path -Path $WorkloadPath))
    {
        New-Item -Path $WorkloadPath -ItemType Directory
    }
    $subscriptionPath = (Join-Path -Path $WorkloadPath -ChildPath $subscriptionObject.Name)
    if(!(Test-Path -Path $subscriptionPath))
    {
        New-Item -Path $subscriptionPath -ItemType Directory
    }
    $tmplocation= (Join-Path -Path "$statePath" -ChildPath "\local")
    if(!(Test-Path -Path $tmplocation )){
     New-Item -Path $tmplocation -ItemType Directory
     } 
     
    # Call DiscoverResources $context pass , try-catch
    DiscoverResources -SubscriptionObject $subscriptionObject
}

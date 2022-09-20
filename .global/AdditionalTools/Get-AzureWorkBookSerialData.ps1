$tenantid      = ""
$SubscriptionName = ""
$resourceGroups = ""
$resourceName   = ""
$token = (Get-AzAccessToken).Token
##Using Token
$tenantID = (Get-AzSubscription -SubscriptionName $SubscriptionName).tenantID
$SubscriptionID = (Get-AzSubscription -SubscriptionName $SubscriptionName).SubscriptionId
## Header for API call
$requestHeader = @{
  "Authorization" = "Bearer " + $token
  "Content-Type" = "application/json"
}
$ApiEndpoint = 'management.azure.com'
$Uri = "https://$ApiEndpoint/subscriptions/$SubscriptionID/resourceGroups/$resourceGroups/providers/Microsoft.Insights/workbooks/$resourceName ?api-version=2021-08-01&canFetchContent=true" 
## Making API call
$Result = Invoke-RestMethod -Method Get -Headers $requestheader -Uri $Uri
## Storing fetched values as Json
$Result.properties | Select-Object displayName,serializedData | ConvertTo-Json
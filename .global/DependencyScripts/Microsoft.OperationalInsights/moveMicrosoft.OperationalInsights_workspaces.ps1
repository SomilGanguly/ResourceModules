# Pre-requisite: Please install the Azure CLI using - https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli

# Here's how you call the script:
# .\moveMicrosoft.OperationalInsights_workspaces.ps1 -branchName ${{ parameters.branchName }}

<#
    .SYNOPSIS
    Export data from one Log Analytics workspace to another workspace.

    .NOTES
    Pre-requisite: Please install the Azure CLI using - https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli

    .ROLE
    1. A Service Principal in the source Azure Active Directory with "User.Read" permission on Microsoft graph
    2. Application (client) Id and client secret of the above SPN should also be stored as secrets in a Key Vault in the destination subscription
    3. The above SPN should have Log Analytics Contributor role on the source Log Analytics workspace
    4. The Service Connection in the pipeline running this script (and thereby, its corresponding SPN), should have Log Analytics Contributor role on the destination Log Analytics workspace
    5. The shared key of the destination Log Analytics workspace should be stored as a secret in the same Key Vault in the destination subscription as above
    6. The Service Connection in the pipeline running this script (and thereby, its corresponding SPN), should have "list, set" access policy permissions on the above Key Vault

    .DESCRIPTION
    Exports data from one Log Analytics workspace to another workspace. Details of source Log Analytics workspace is fetched using the App Id and client secret variables stored in an Azure DevOps variable group. Details of target Log Analytics workspace is fetched by the service connection itself running this script in the pipeline.
    Since, the shared key of the destination workspace is used, hence, data can be copied in a workspace which is in a different region or in a different tenant altogether.

    .PARAMETER SrcTenantId
    Mandatory. Tenant Id of the source subscription.

    .PARAMETER SrcSubscriptionId
    Mandatory. Subscription Id of the Log Analytics workspace from where the archival data needs to be copied.

    .PARAMETER SrcWorkspaceResourceGroupName
    Mandatory. Resource group name of the source Log Analytics workspace.

    .PARAMETER SrcWorkspaceName
    Mandatory. Name of the source Log Analytics workspace.

    .PARAMETER Query
    Mandatory. The Kusto query to filter the archival data. Records filtered by this particular query only will be exported and copied into the destination Log Analytics workspace.

    .PARAMETER DestSubscriptionId
    Mandatory. Subscription Id of the destination Log Analytics workspace in which the exported archival data needs to be copied.

    .PARAMETER DestWorkspaceResourceGroupName
    Mandatory. Resource group name of the destination Log Analytics workspace.

    .PARAMETER DestWorkspaceName
    Mandatory. Name of the destination Log Analytics workspace

    .PARAMETER KeyVaultName
    Mandatory. Name of the Key Vault containing the 3 secrets explained below.

    .PARAMETER SrcSPNAppIdSecretName
    Mandatory. Name of the secret containing the app (client) Id of the SPN.

    .PARAMETER SrcSPNClientSecretSecretName
    Mandatory. Name of the secret containing the client secret of the SPN.

    .PARAMETER DestWorkspaceSharedKeySecretName
    Mandatory. Name of the secret containing the shared key of the destination workspace.

    .EXAMPLE
    Here's how you call the script:
    .\moveMicrosoft.OperationalInsights_workspaces -branchName ${{ parameters.branchName }}

    .OUTPUTS
    No. of records which were successfully copied.
#>

Param(
    [parameter(mandatory)] [string] $branchName
)


$SrcTenantId = ""
$SrcSubscriptionId = ""
$SrcWorkspaceResourceGroupName = ""
$SrcWorkspaceName = ""
$Query = ""
$DestSubscriptionId = ""
$DestWorkspaceResourceGroupName = ""
$DestWorkspaceName = ""
$KeyVaultName = ""
$SrcSPNAppIdSecretName = ""
$SrcSPNClientSecretSecretName = ""
$DestWorkspaceSharedKeySecretName = ""
$executeScript = $true

# Create the function to create the authorization signature
Function Build-Signature ($DestWorkspaceCustomerId, $DestWorkspaceSharedKey, $Date, $ContentLength, $Method, $ContentType, $Resource) {
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $destWorkspaceSharedKeyString = ConvertFrom-SecureString -SecureString $DestWorkspaceSharedKey -AsPlainText
    $keyBytes = [Convert]::FromBase64String($destWorkspaceSharedKeyString)
    Remove-Variable -Name destWorkspaceSharedKeyString -Scope Global -Force -ErrorAction SilentlyContinue

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $($destWorkspace.CustomerId),$encodedHash
    Return $authorization
}

# Create the function to create and post the request
Function Send-LogAnalyticsData ($DestWorkspaceCustomerId, $DestWorkspaceSharedKey, $Body, $LogType, $TimeStampField) {
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature -DestWorkspaceCustomerId $($destWorkspace.CustomerId) `
                                 -DestWorkspaceSharedKey $DestWorkspaceSharedKey `
                                 -Date $rfc1123date `
                                 -ContentLength $contentLength `
                                 -Method $method `
                                 -ContentType $contentType `
                                 -Resource $resource
    $uri = "https://" + $($destWorkspace.CustomerId) + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $LogType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }

    $response = Invoke-WebRequest -Uri $uri `
                                  -Method $method `
                                  -ContentType $contentType `
                                  -Headers $headers `
                                  -Body $body `
                                  -UseBasicParsing
    Return $($response.StatusCode)
}

# Get the variable group which contains variables for the SPN containing App Id and client secret to authenticate to the source environment.
Function Get-AzureDevOpsVariableGroup ($Name) {
    $uri = New-Object System.UriBuilder "$($env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI)$env:SYSTEM_TEAMPROJECTID"
    $uri.Path += "/_apis/distributedtask/variablegroups"
    $uri.Query += "groupName=$Name&api-version=6.0-preview.2"
    Write-Host "Absolute URI built: '$($uri.Uri.AbsoluteUri)'."
    $variableGroupAuthHeader = @{
        Authorization = "Bearer $env:SYSTEM_ACCESSTOKEN"
    }
    $variableGroup = Invoke-RestMethod -Uri $($uri.Uri.AbsoluteUri) -Headers $variableGroupAuthHeader

    Return $($variableGroup.value)
}

Function moveMicrosoft.OperationalInsights_workspaces {
    Param (

        [Parameter(Mandatory = $true)]
        [String] $SrcTenantId,

        [Parameter(Mandatory = $true)]
        [String] $SrcSubscriptionId,

        [Parameter(Mandatory = $true)]
        [String] $SrcWorkspaceResourceGroupName,

        [Parameter(Mandatory = $true)]
        [String] $SrcWorkspaceName,

        [Parameter(Mandatory = $true)]
        [String] $Query,

        [Parameter(Mandatory = $true)]
        [String] $DestSubscriptionId,

        [Parameter(Mandatory = $true)]
        [String] $DestWorkspaceResourceGroupName,

        [Parameter(Mandatory = $true)]
        [String] $DestWorkspaceName,

        [Parameter(Mandatory = $true)]
        [String] $KeyVaultName,

        [Parameter(Mandatory = $true)]
        [String] $SrcSPNAppIdSecretName,

        [Parameter(Mandatory = $true)]
        [String] $SrcSPNClientSecretSecretName,

        [Parameter(Mandatory = $true)]
        [String] $DestWorkspaceSharedKeySecretName,

        [Parameter(Mandatory = $true)]
        [String] $branchName

    )

    Set-StrictMode -Version Latest
    $VerbosePreference = 'Continue'
    $ErrorActionPreference = "Stop"

    Try {
        Write-Verbose "Fetching details of the source SPN from the '$($KeyVaultName)' key vault to login in the source tenant and subscription."
        $srcSPNAppId = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SrcSPNAppIdSecretName).SecretValue `
                            | ConvertFrom-SecureString -AsPlainText
        $srcSPNClientSecret = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SrcSPNClientSecretSecretName).SecretValue
        $psCredential = New-Object -TypeName System.Management.Automation.PSCredential `
                                   -ArgumentList $srcSPNAppId, $srcSPNClientSecret
        Connect-AzAccount -ServicePrincipal -Credential $psCredential -Tenant $SrcTenantId
        Remove-Variable -Name srcSPNClientSecret -Scope Global -Force -ErrorAction SilentlyContinue

        Write-Host "Setting context for source subscription."
        Set-AzContext -Subscription $SrcSubscriptionId
        Write-Verbose "Fetching details of the workspace: '$($SrcWorkspaceName)'."
        $srcWorkspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $SrcWorkspaceResourceGroupName `
                                                           -Name $SrcWorkspaceName
        Write-Verbose "Fetching results based on the query."
        $queryResponse = Invoke-AzOperationalInsightsQuery -Workspace $srcWorkspace -Query $query
        Write-Verbose "Converting fetched results to an array."
        $recordsArray = [System.Linq.Enumerable]::ToArray($queryResponse.Results)
        $recordCount = 0
        Foreach ($record in $recordsArray) {
            $recordCount += 1
        }
        Write-Host "No. of archive records returned by the query: '$($recordCount)'."
        Write-Verbose "Disconnecting source Azure account."
        Disconnect-AzAccount -ApplicationId $srcSPNAppId -TenantId $SrcTenantId -Confirm:$false

        Write-Host "Setting context for destination subscription."
        Set-AzContext -Subscription $DestSubscriptionId
        Write-Verbose "Fetching details of the workspace: '$($DestWorkspaceName)'."
        $destWorkspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $DestWorkspaceResourceGroupName `
                                                            -Name $DestWorkspaceName
        Write-Verbose "Fetching the destination workspace's shared key from the '$($DestWorkspaceSharedKeySecretName)' secret in '$($KeyVaultName)' key vault."
        $sharedKey = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $DestWorkspaceSharedKeySecretName).SecretValue
        $recordCount = 0
        Foreach ($record in $recordsArray) {
            $jsonData = @"
[$($record | ConvertTo-Json)]
"@
            $recordCount += 1
            Write-Verbose ""
            Write-Verbose "Posting record no.: '$($recordCount)'."
            # Submit the data to the API endpoint
            $postResponse = Send-LogAnalyticsData -DestWorkspaceCustomerId $($destWorkspace.CustomerId) `
                                                  -DestWorkspaceSharedKey $sharedKey `
                                                  -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonData)) `
                                                  -LogType $($record.Type) `
                                                  -TimeStampField $($record.TimeGenerated)
            If ($postResponse -eq 200) {
                Write-Verbose "Successfully posted record no. '$($recordCount)'."
            }
        }
        Write-Host "Successfully copied all '$($recordCount)' archival records from '$($SrcWorkspaceName)' to '$($DestWorkspaceName)'."
    }
    Catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
    }
}

If ($executeScript)
{
    moveMicrosoft.OperationalInsights_workspaces -SrcTenantId $SrcTenantId `
                                                 -SrcSubscriptionId $SrcSubscriptionId `
                                                 -SrcWorkspaceResourceGroupName $SrcWorkspaceResourceGroupName `
                                                 -SrcWorkspaceName $SrcWorkspaceName `
                                                 -Query $Query `
                                                 -DestSubscriptionId $DestSubscriptionId `
                                                 -DestWorkspaceResourceGroupName $DestWorkspaceResourceGroupName `
                                                 -DestWorkspaceName $DestWorkspaceName `
                                                 -KeyVaultName $KeyVaultName `
                                                 -SrcSPNAppIdSecretName $SrcSPNAppIdSecretName `
                                                 -SrcSPNClientSecretSecretName $SrcSPNClientSecretSecretName `
                                                 -DestWorkspaceSharedKeySecretName $DestWorkspaceSharedKeySecretName `
                                                 -branchName $branchName
}
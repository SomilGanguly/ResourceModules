# Pre-requisite: Please install the Azure CLI using - https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli

# Access Reqiurments: A contribute access is required to both the source and target Sql servers. 

#  Description: This script does the following activities within the same subscription.
#  Basically this is a strategy to move sql Databases to the Secondary region through Failover groups.
#  Creates a SQL Failover Group
#  Adds the SQL Databases from Source SQL Server into Failover Group
#  Replicates the SQL Data on the Secondary
#  Switches the Secondary SQL Server as Primary

# Here's how you call the script:
# .\moveMicrosoft.sql.ps1 -branchName ${{ parameters.branchName }}

Param(
    [parameter(mandatory)] [string] $branchName
)

$subscriptionId = 'xxxxxx'
$targetRg = "xxxxx"
$sourceRg = "xxxx"
$serverName = "xxxxx"
$drServerName = "xxxx"
$failoverGroupName = "xxxxx"
$executeScript = 'true'

function moveMicrosoft.sql{
Param(
    [parameter(mandatory)] [string] $subscriptionId,
    [parameter(mandatory)] [string] $targetRg,
    [parameter(mandatory)] [string] $sourceRg,
    [parameter(mandatory)] [string] $serverName,
    [parameter(mandatory)] [string] $drServerName,
    [parameter(mandatory)] [string] $failoverGroupName,    
    [parameter(mandatory)] [string] $branchName
)

try{
# Create a failover group between the servers
echo "Creating Failover group - $failoverGroupName between $serverName and $drServerName..."
az sql failover-group create --name $failoverGroupName --partner-server $drServerName --partner-resource-group $targetRg --server $serverName --resource-group $sourceRg  --failover-policy Automatic --grace-period 2

# Getting the Databases from source sql server
echo "Getting the databases from Source Sql server..."
$databases = az sql db list --resource-group $sourceRg --server $serverName |ConvertFrom-Json

# Add the database to the failover group
echo "Adding the database to the failover group..."
foreach ($db in $databases)
{
   $dbName = $db.name
   $dbId = $db.id
az sql failover-group update --name $failoverGroupName --add-db $dbName --ids $dbId
}
Write-host "Successfully added the database to the failover group..."

# Failover to the Secondary server

echo "Failing over to $drServerName..."
az sql failover-group set-primary --name $failoverGroupname --resource-group $targetRg --server $drServerName 

echo "Confirming role of $drServerName is now primary..."
az sql failover-group show --name $failoverGroupname  --resource-group $targetRg --server $drServerName

Write-host "SQL Databases has successfully moved"
}
catch{
$statePath = $pwd
Import-Module "$statePath/src/internal/functions/Log-Exceptions.ps1" -Force 
$scriptPath= ($MyInvocation.MyCommand).Definition
$scriptName= ([io.fileinfo]$MyInvocation.MyCommand.Definition).BaseName

$settinglocation=(Get-ChildItem -Path "$statePath/src/").Name
foreach($locationfile in $settinglocation){
if($locationfile -match "_Settings.json")
{
$settingfile=get-content -path "$statePath/src/$locationfile"
$logPath=($settingfile | ConvertFrom-Json).RelocationSettings.LogPath 
}
}
$Result = ""
if($Error.Count){ $Result = "Failed"}
Log-Exceptions -ScriptName $scriptName -LogPath "$statePath/$logPath" -Exception "$PSItem.Exception.Message" -Result $Result -ScriptPath $scriptPath -branchName $branchName
}
}

if($executeScript -eq 'true')
{
moveMicrosoft.sql -subscriptionId $subscriptionId -tgtrg $targetRg -srcrg $sourceRg -serverName $serverName -drServerName $drServerName -failoverGroupName $failoverGroupName -branchName $branchName
}
##
## This script is called in the DiscoverResources.ps1 script.
## It is used for populating the parameters in the
## parameter files for discovered resources' parameter file. 
## The parameters are picked from the setting.json file 
## and DefaultParameterTemplate.json file.
##

function Generate-ARMParameters{
    Param(
        [parameter(mandatory)][string] $exportedArmLocation,
        [parameter(mandatory)][string] $proccessedArmLocation,
        [string]$statePath = $pwd
    )
$actualJson=get-content -path $exportedArmLocation
$convertactualJson=$actualJson | ConvertFrom-Json
$parameterObjs =  get-content -path ".\src\data\DefaultParameterTemplate.json"
$parameterObj=$parameterObjs | ConvertFrom-Json
$settingfile=get-content -path "$statePath/src/Settings.json"
$RelocationSettings=($settingfile | ConvertFrom-Json).RelocationSettings.TargetLocation
foreach($params in $convertactualJson.parameters)
{
    $names=($params | Get-Member -MemberType *Property).Name
    foreach($name in $names)
    {
        if($name -match "location_*")
        {
            $value=$params.$name.defaultValue
            $value= $RelocationSettings
        }
        else
        {
            $value=$params.$name.defaultValue
        } 
        $paramRequest = @{
        "value"= $value
            }        
        $parameterObj.parameters | Add-Member -Name $name -MemberType NoteProperty -Value $paramRequest          
    }
}
$processedParameter=$parameterObj | ConvertTo-Json -Depth 100 
$processedParameter | Out-File -FilePath $proccessedArmLocation 
}
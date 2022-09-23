
function Get-CustomParameterObj {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [PSCustomObject] $obj,

        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [PSCustomObject] $parameterObj,

        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [string] $objectType
    )
    $ParamsToExclude = @("apiVersion", "dependsOn")
    
    if ($obj){
        $obj | Get-Member -MemberType NoteProperty | ForEach-Object {
        $tempKey= $_.Name
        $jsonRequest = @{
                            "value" = $obj.$tempKey
                        }
        $parameterObj.parameters | Where-Object {
            $tempKey -notin $ParamsToExclude } | Add-Member -Name $tempKey -MemberType NoteProperty -Value $jsonRequest

        if($obj.$tempKey) { Get-CustomParameterObj -obj $obj.$tempKey -parameterObj $parameterObj.parameters -objectType $objectType}
        else{ return $parameterObj.parameters}
        }
    }
}

function Get-SubResourceObjectType {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [string]$resourceType,

        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [string]$subType,

        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [string]$carmlPath
    )
    # Use the Parent Module for Building arm template.
    $modulePath = $carmlPath+$resourceType.Replace("/"+$subType,"")

    # Build Json for parsing the parameters
    az bicep build -f $modulePath/deploy.bicep

    # Getting the json file as pscustomobject
    $carmlContent = (Get-Content $modulePath/deploy.json) | ConvertFrom-Json 

    Write-Host $subType " : " $carmlContent.parameters.$subType.type
    return $carmlContent.parameters.$subType.type
}
function Convert-ARMToBicepParameters {
    Param(
        [parameter(mandatory)][string] $exportedArmLocation,
        [parameter(mandatory)][string] $proccessedArmLocation
    )
    Write-Host $exportedArmLocation
    Write-Host $proccessedArmLocation
    $inputJson = Get-content -Path $exportedArmLocation
    $jsonConvertInputJson = $inputJson | ConvertFrom-Json

    $parameterObjs = Get-content -path "C:/Users/siddhigupta.FAREAST/app-code/CARMLExport/src/data/DefaultParameterTemplate.json"
    $parameterObj = $parameterObjs | ConvertFrom-Json

    foreach ($eachResourceInputJson in $jsonConvertInputJson.resources) {
        #$eachResourceInputJson = $jsonConvertInputJson.resources[0]
        $resourceType = $eachResourceInputJson.type
        Write-Host "-----" $resourceType "-----"
        
        if ( $resourceType.Split("/").Length -gt 2){
            $subtypeFull =  $resourceType
            $subType = $subtypeFull.Split('/', 3)
        } 
        else { $subtypeFull = "" }
    
        if ($subtypeFull) {

            ## Call to find sub-resource object type
            $objectType = Get-SubResourceObjectType -resourceType $resourceType  -subType $subType[$subType.Length - 1] -carmlPath $carmlPath
        } 
        else { Write-Host "No sub type" }
    
        ## Call to find generate parameters object
        Get-CustomParameterObj -obj $eachResourceInputJson -parameterObj $parameterObj.parameters -objectType $objectType
    }

    # $jqJsonTemplate = "$statePath/src/storage_parameter_jq.jq"
    # $parameterToObj = ($parameters | ConvertTo-Json -Depth 100 | jq -r -f $jqJsonTemplate | ConvertFrom-Json)
    Write-Host "parameter to object" $parameterToObj
    #ConvertTo-Json -InputObject $parameterToObj -Depth 100 | Set-Content -Path $proccessedArmLocation
}

$tempExportPath = 'C:/Users/siddhigupta.FAREAST/app-code/CARMLExport/Infra_Apps/rakshana_subscription/cost/Microsoft.Storage_storageAccounts/westredisrak.deploy.json'
$paramExportPath = 'C:/Users/siddhigupta.FAREAST/app-code/CARMLExport/Infra_Apps/rakshana_subscription/cost/Microsoft.Storage_storageAccounts/parameters/param_storage.json'
Convert-ARMToBicepParameters -exportedArmLocation $tempExportPath -proccessedArmLocation $paramExportPath


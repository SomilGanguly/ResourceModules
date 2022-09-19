##
## This script is used in the relocation pipeline.
## Gets called in DiscoverResources.ps1 script.
##

function Curated-ExportedARM{
    Param(
        [parameter(mandatory)][string] $exportedArmLocation,
        [parameter(mandatory)][string] $proccessedArmLocation
    )

$inputJson=get-content -Path $exportedArmLocation
$jsonConvertInputJson=$inputJson | ConvertFrom-Json
$count=0
foreach($eachInputJason in $jsonConvertInputJson)
{
    foreach($eachResourceInputJason in $eachInputJason.resources)
    {
        $resourcetypemod=$eachInputJason.resources[$count].type.Replace('/','_')
        $memberType=($eachResourceInputJason | Get-Member -MemberType *Property).Name
        foreach($member in $memberType) 
        {
            if($member -inotin @("type","dependsOn") ) 
            {
                $property1=$member + '_' +$resourcetypemod + '_' +$count
                $property2=$eachResourceInputJason.$member
                $jsonConvertInputJson.resources[$count].$member = "[parameters('"+$property1+"')]"
                if(!($property2))
                {
                    $property3 = "Object"
                }
                elseif(($property2.GetType()).name -eq "PSCustomObject")
                {
                    $property3 = "Object"
                }
                else
                {
                    $property3 = "String"
                }
            
                if(!($property2))
                {
                    $jsonRequest = @{
                    "type"= $property3
                                    }
                }
                else{
                    $jsonRequest = @{
                    "defaultValue"= $property2
                    "type"= $property3
                                    }
                }

                $jsonConvertInputJson.parameters | Add-Member -Name $property1 -MemberType NoteProperty -Value $jsonRequest
            }
        }
        $deployState= "deployState"+ '_'+ $resourcetypemod + '_' +$count
        $conditionFormate = "[equals(parameters('"+$deployState+"'),'Yes')]"
        $jsonConvertInputJson.resources[$count] | Add-Member -Name "Condition" -MemberType NoteProperty -Value $conditionFormate
        $jsonRequest = @{
                "defaultValue"= "Yes"
                "type"= "String"
                "allowedValues"="Yes","No"
                }

        $jsonConvertInputJson.parameters | Add-Member -Name $deployState -MemberType NoteProperty -Value $jsonRequest
        $count+=1
    }
}
$actualJson=$jsonConvertInputJson | ConvertTo-Json -Depth 100
echo $actualJson |  Out-File -FilePath $proccessedArmLocation
}

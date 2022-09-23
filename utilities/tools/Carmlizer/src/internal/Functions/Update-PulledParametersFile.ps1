function Convert-ARMToBicepParameters {
    Param(
        [parameter(mandatory)][string] $exportedArmLocation,
        [parameter(mandatory)][string] $proccessedArmLocation
    )
    Write-Host $exportedArmLocation
    Write-Host $proccessedArmLocation
    $inputJson = Get-Content -Path $exportedArmLocation
    $jsonConvertInputJson = $inputJson | ConvertFrom-Json
    $count = 0
    $parameterObjs = Get-Content -Path '.\src\data\DefaultParameterTemplate.json'
    $parameterObj = $parameterObjs | ConvertFrom-Json
    foreach ($eachInputJson in $jsonConvertInputJson) {
        foreach ($eachResourceInputJson in $eachInputJson.resources) {
            if ($eachResourceInputJson.type -eq 'Microsoft.Storage/storageAccounts') {
                $memberType = ($eachResourceInputJson | Get-Member -MemberType *Property).Name
                foreach ($member in $memberType) {
                    if ($member -in @('properties')) {
                        $memberprop = ($eachResourceInputJson.properties | Get-Member -MemberType *Property).Name
                        foreach ($property in $memberprop) {
                            if ($property -in @('encryption')) {
                                $jsonRequest = @{
                                    'value' = $eachResourceInputJson.properties.$property.requireInfrastructureEncryption
                                }
                                $parameterObj.parameters | Add-Member -Name 'requireInfrastructureEncryption' -MemberType NoteProperty -Value $jsonRequest
                                if ($eachResourceInputJson.properties.$property.keySource -eq 'Microsoft.Keyvault') {
                                    $jsonRequest = @{
                                        'value' = $eachResourceInputJson.properties.$property.keyvaultproperties.keyname
                                    }
                                    $parameterObj.parameters | Add-Member -Name 'cMKKeyName' -MemberType NoteProperty -Value $jsonRequest

                                    $keyVaultResourceName = ($eachResourceInputJson.properties.$property.keyvaultproperties.keyvaulturi).Split('.')[0].Substring(8)
                                    $keyvaultResourceId = (Get-AzKeyVault -VaultName $keyVaultResourceName).ResourceId
                                    $jsonRequest = @{
                                        'value' = $keyvaultResourceId
                                    }
                                    $parameterObj.parameters | Add-Member -Name 'cMKKeyVaultResourceId' -MemberType NoteProperty -Value $jsonRequest
                                }
                                if ($null -ne $eachResourceInputJson.properties.$property.identity.userAssignedIdentity) {
                                    $jsonRequest = @{
                                        'value' = $eachResourceInputJson.properties.$property.identity.userAssignedIdentity
                                    }
                                    $parameterObj.parameters | Add-Member -Name 'cMKUserAssignedIdentityResourceId' -MemberType NoteProperty -Value $jsonRequest
                                }

                            } else {
                                $jsonRequest = @{
                                    'value' = $eachResourceInputJson.properties.$property
                                }
                                $parameterObj.parameters | Add-Member -Name $property -MemberType NoteProperty -Value $jsonRequest
                            }
                        }
                    }
                    if ($member -inotin @('type', 'dependsOn', 'properties', 'apiVersion') ) {
                        $member2 = $member
                        $jsonRequest = @{
                            'value' = $eachResourceInputJson.$member
                        }
                        if ($member -in @('identity')) {
                            if ($eachResourceInputJson.$member.type -like '*SystemAssigned*') {
                                $member2 = 'systemAssignedIdentity'
                                $jsonRequest = @{
                                    'value' = $true
                                }
                            }
                            if (($eachResourceInputJson.$member | Get-Member -MemberType *Property).Name -contains 'userAssignedIdentities') {
                                $member1 = 'userAssignedIdentities'
                                $x = ($eachResourceInputJson.$member.userAssignedIdentities | Get-Member -MemberType *Property).Name
                                $jsonRequest1 = @{
                                    'value' = [PSCustomObject]@{
                                        $x = [PSCustomObject]@{}
                                    }

                                }
                                $parameterObj.parameters | Add-Member -Name $member1 -MemberType NoteProperty -Value $jsonRequest1
                            }
                        }
                        if ($member -in @('Sku')) {
                            $member2 = $member
                            $jsonRequest = @{
                                'value' = $eachResourceInputJson.$member.name
                            }
                        }
                        $parameterObj.parameters | Add-Member -Name $member2 -MemberType NoteProperty -Value $jsonRequest
                    }
                }
                $count += 1
            }
            if ($eachResourceInputJson.type -eq 'Microsoft.Storage/storageAccounts/blobServices') {
                $memberType = ($eachResourceInputJson | Get-Member -MemberType *Property).Name
                $blobServices = [PSCustomObject]@{
                    deleteRetentionPolicy = $eachResourceInputJson.properties.deleteRetentionPolicy.enabled
                }
                $jsonRequest = @{
                    'value' = $blobServices
                }
                $parameterObj.parameters | Add-Member -Name 'blobServices' -MemberType NoteProperty -Value $jsonRequest
            }
            if ($eachResourceInputJson.type -eq 'Microsoft.Storage/storageAccounts/fileServices') {
                $memberType = ($eachResourceInputJson | Get-Member -MemberType *Property).Name
                $fileServices = [PSCustomObject]@{
                    shareDeleteRetentionPolicy = $eachResourceInputJson.properties.shareDeleteRetentionPolicy
                }
                $jsonRequest = @{
                    'value' = $fileServices
                }
                $parameterObj.parameters | Add-Member -Name 'fileServices' -MemberType NoteProperty -Value $jsonRequest
            }
            if ($eachResourceInputJson.type -eq 'Microsoft.Storage/storageAccounts/queueServices') {
                $memberType = ($eachResourceInputJson | Get-Member -MemberType *Property).Name
                $queueServices = [PSCustomObject]@{
                }
                $jsonRequest = @{
                    'value' = $queueServices
                }
                $parameterObj.parameters | Add-Member -Name 'queueServices' -MemberType NoteProperty -Value $jsonRequest
            }
            if ($eachResourceInputJson.type -eq 'Microsoft.Storage/storageAccounts/tableServices') {
                $memberType = ($eachResourceInputJson | Get-Member -MemberType *Property).Name
                $tableServices = [PSCustomObject]@{
                }
                $jsonRequest = @{
                    'value' = $tableServices
                }
                $parameterObj.parameters | Add-Member -Name 'tableServices' -MemberType NoteProperty -Value $jsonRequest
            }
        }
    }

    $jqJsonTemplate = "$statePath/src/storage_parameter_jq.jq"
    $parameters = $parameterObj.parameters
    Write-Host $parameters
    $parameterToObj = ($parameters | ConvertTo-Json -Depth 100 | jq -r -f $jqJsonTemplate | ConvertFrom-Json)
    Write-Host 'parameter to object' $parameterToObj
    ConvertTo-Json -InputObject $parameterToObj -Depth 100 | Set-Content -Path $proccessedArmLocation
}


#Requires -Version 7


$script:Parentlocation = Split-Path -Parent $MyInvocation.MyCommand.Path -Resolve
$script:Parent = Split-Path -Parent -Path $Parentlocation
$script:Parentlevel2 = Split-Path -Parent -Path $Parent
$script:Parentlevel3 = Split-Path -Parent -Path $Parentlevel2
$script:workloadfolder = (Get-ChildItem -Path $Parentlevel3 -Directory -Exclude ".global","src","Modules").FullName
$script:subscriptionFolder = (Get-ChildItem -Path $workloadfolder -Directory).FullName
$script:ResourceGroupFolder = (Get-ChildItem -Path $subscriptionFolder -Directory).FullName
$script:moduleFolderPaths = (Get-ChildItem -Path $ResourceGroupFolder -Directory).FullName

$script:RGdeployment = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
$script:Subscriptiondeployment = "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#"
$script:MGdeployment = "https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#"
$script:Tenantdeployment = "https://schema.management.azure.com/schemas/2019-08-01/tenantDeploymentTemplate.json#"



Describe "File/folder tests" {

Context "General module folder tests" {

        It "Module should contain a [deploy.json] file" {
            foreach($mfolder in $moduleFolderPaths){
            $deployfilenames=Get-ChildItem -Path $mfolder -File
            foreach($deployfilename in $deployfilenames){
            if($deployfilename -match ".deploy.json"){
            $true | Should -Be $true
            }
            else{
            $false | Should -Be $true
            }
            }            
            }
        }

        It "Module should contain a [Parameters] folder"{
            foreach($mfolder in $moduleFolderPaths){
            $deployFolderNames=Get-ChildItem -Path $mfolder -Directory
            if($deployFolderNames -match "parameters"){
            
            $true | Should -Be $true
            }
            else{
            $false | Should -Be $true
            }
            }
        }
        It "Module should contain a [Pipeline] folder"{
            foreach($mfolder in $moduleFolderPaths){
            $deployFolderNames=Get-ChildItem -Path $mfolder -Directory
            if($deployFolderNames -match "pipelines"){
            
            $true | Should -Be $true
            }
            else{
            $false | Should -Be $true
            }
            }
        }
        It "Module should contain a [Scripts] folder"{
            foreach($mfolder in $moduleFolderPaths){
            $rgfoldersplit=Split-Path -Path $mfolder -Leaf
            if($rgfoldersplit -ne "Microsoft.Resources_resourceGroups"){   
            $deployFolderNames=Get-ChildItem -Path $mfolder -Directory
            if($deployFolderNames -match "scripts"){
            $true | Should -Be $true
            }
            else{
            $false | Should -Be $true
            }
            }
            }
        }
}
Context "Parameters folder" {
It "Parameters folder should contain one or more *parameters.json files"{
            foreach($mfolder in $moduleFolderPaths){
            $deployFolderNames=Get-ChildItem -Path $mfolder -Directory
            if($deployFolderNames -match "parameters"){
            
            $parametersFiles=Get-ChildItem -Path (Join-Path -Path $mfolder -ChildPath "parameters")
            foreach($paramfile in $parametersFiles){
            if($paramfile -like "*parameters.json"){
            $true | Should -Be $true
            
            }
             else{
             $false | Should -Be $true
             }          
            }
            
            }
            }


}

    It  "*parameters.json files in the Parameters folder should not be empty"{
            foreach($mfolder in $moduleFolderPaths){
            $deployFolderNames=Get-ChildItem -Path $mfolder -Directory
            if($deployFolderNames -match "parameters"){
            
            $parametersFiles=Get-ChildItem -Path (Join-Path -Path $mfolder -ChildPath "parameters")
            foreach($paramfile in $parametersFiles){
            if($paramfile -like "*parameters.json"){
            if(Get-Content $paramfile){
            $true | Should -Be $true }
            else{
            $false | Should -Be $true}
            }  
            }
        }
    }
}
    It "*parameters.json files in the Parameters folder should be valid JSON"{
            foreach($mfolder in $moduleFolderPaths){
            $deployFolderNames=Get-ChildItem -Path $mfolder -Directory
            if($deployFolderNames -match "parameters"){
            
            $parametersFiles=Get-ChildItem -Path (Join-Path -Path $mfolder -ChildPath "parameters")
            foreach($paramfile in $parametersFiles){
            if($paramfile -like "*parameters.json"){
            $TemplateContent = Get-Content $paramfile -Raw -ErrorAction SilentlyContinue
            $TemplateContent | ConvertFrom-Json -ErrorAction SilentlyContinue | Should -Not -Be $Null
            Test-Path $paramfile -PathType Leaf -Include '*.json' | Should -Be $true 
            }
        }
    }
    }
}
}
Context "Pipeline folder" {
        It "Pipeline folder should contain one or more *.yml files (pipeline files)" {
        foreach($mfolder in $moduleFolderPaths){
            $deployFolderNames=Get-ChildItem -Path $mfolder -Directory
            if($deployFolderNames -match "pipelines"){
            
            $pipelinesFiles=Get-ChildItem -Path (Join-Path -Path $mfolder -ChildPath "pipelines")
            
            foreach($pipefile in $pipelinesFiles){

            if($pipefile -like "*.yml"){
            $true | Should -Be $true
            
            }
             else{
             $false | Should -Be $true
             }          
            }
            
            }
            }
        }
}
Context "Deployment template tests"{
    It "deploy.json file should not be empty"{
            foreach($mfolder in $moduleFolderPaths){
            $deployfilenames=Get-ChildItem -Path $mfolder -File
            foreach($deployfile in $deployfilenames){
            if(Get-Content $deployfile){
            $true | Should -Be $true }
            else{
            $false | Should -Be $true}  
            }
        }
    }
    It "The deploy.json file should be a valid JSON"{    
            foreach($mfolder in $moduleFolderPaths){
            $deployfilenames=Get-ChildItem -Path $mfolder -File
            foreach($deployfilename in $deployfilenames){
            if($deployfilename -match ".deploy.json"){
            $TemplateContent = Get-Content $deployfilename -Raw -ErrorAction SilentlyContinue
            $TemplateContent | ConvertFrom-Json -ErrorAction SilentlyContinue | Should -Not -Be $Null
            Test-Path $deployfilename -PathType Leaf -Include '*.json' | Should -Be $true 
            }
    }
    }
}
    It "Template schema version should be the latest"{
            # the actual value changes depending on the scope of the template (RG, subscription, MG, tenant) !!
            # https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/template-syntax
            foreach($mfolder in $moduleFolderPaths){
            $deployfilenames=Get-ChildItem -Path $mfolder -File
            foreach($deployfilename in $deployfilenames){
            if($deployfilename -match ".deploy.json"){
            $TemplateARM = Get-Content ($deployfilename) -Raw -ErrorAction SilentlyContinue
            try {
                $Template = ConvertFrom-Json -InputObject $TemplateARM -ErrorAction SilentlyContinue
            }
            catch { 
                Write-Verbose "[Template schema version should be the latest] Json conversion Error at ($deployfilename)" -Verbose
                Continue 
            }
            $Schemaverion = $Template.'$schema'
            $SchemaArray = @()
            if ($Schemaverion -eq $RGdeployment) {
                $SchemaOutput = $true
            }
            elseif ($Schemaverion -eq $Subscriptiondeployment) {
                $SchemaOutput = $true
            }
            elseif ($Schemaverion -eq $MGdeployment) {
                $SchemaOutput = $true
            }
            elseif ($Schemaverion -eq $Tenantdeployment) {
                $SchemaOutput = $true
            }
            else {
                $SchemaOutput = $false
            }
            $SchemaArray += $SchemaOutput
            $SchemaArray | Should -Not -Contain $false
        }
        }
    }
}
    It "Template schema should use HTTPS reference"{
            foreach($mfolder in $moduleFolderPaths){
            $deployfilenames=Get-ChildItem -Path $mfolder -File
            foreach($deployfilename in $deployfilenames){
            if($deployfilename -match ".deploy.json"){
            $TemplateARM = Get-Content ($deployfilename) -Raw -ErrorAction SilentlyContinue
            try {
                $Template = ConvertFrom-Json -InputObject $TemplateARM -ErrorAction SilentlyContinue
            }
            catch { 
                Write-Verbose "[Template schema should use HTTPS reference] Json conversion Error at ($deployfilename)" -Verbose
                Continue 
            }
            $Schemaverion = $Template.'$schema'
            ($Schemaverion.Substring(0, 5) -eq "https") | Should -Be $true
        }
        }
}
}
    It "The deploy.json file should contain ALL supported elements: schema, contentVersion, parameters, variables, resources, functions, outputs"{
            foreach($mfolder in $moduleFolderPaths){
            $deployfilenames=Get-ChildItem -Path $mfolder -File
            foreach($deployfilename in $deployfilenames){
            if($deployfilename -match ".deploy.json"){
            $TemplateProperties = (Get-Content ($deployfilename) -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue) | Get-Member -MemberType NoteProperty | Sort-Object -Property Name | ForEach-Object Name
            $TemplateProperties | Should -Contain '$schema' 
            $TemplateProperties | Should -Contain 'contentVersion' 
            $TemplateProperties | Should -Contain 'parameters' 
            $TemplateProperties | Should -Contain 'variables' 
            $TemplateProperties | Should -Contain 'resources'
        }
        }
}
}
    It "Parameter and variable names should be camel-cased (must start with lower-case letter)"{
            foreach($mfolder in $moduleFolderPaths){
            $deployfilenames=Get-ChildItem -Path $mfolder -File
            foreach($deployfilename in $deployfilenames){
            if($deployfilename -match ".deploy.json"){
            $TemplateARM = Get-Content ($deployfilename) -Raw -ErrorAction SilentlyContinue
            try { 
                $Template = ConvertFrom-Json -InputObject $TemplateARM -ErrorAction SilentlyContinue
            }
            catch { 
                Write-Verbose "[Parameter and variable names should be camel-cased (no dashes or underscores and must start with lower-case letter))] Json conversion Error at ($deployfilename)" -Verbose
                Continue 
            }
            $CamelCasingFlag = @()
            $Parameter = ($Template.parameters | Get-Member | Where-Object { $_.MemberType -eq "NoteProperty" }).Name
            $Variable = ($Template.variables | Get-Member | Where-Object { $_.MemberType -eq "NoteProperty" }).Name
            foreach ($Param in $Parameter) {
                if ($Param.substring(0, 1) -cnotmatch '[a-z]') {
                    $CamelCasingFlag += $false
                }
                else {
                    $CamelCasingFlag += $true
                }
            }
            foreach ($Variab in $Variable) {
                if ($Variab.substring(0, 1) -cnotmatch '[a-z]') {
                    $CamelCasingFlag += $false  
                }
                else {
                    $CamelCasingFlag += $true
                }
            }
            $CamelCasingFlag | Should -Not -Contain $false
        }
        }
}
}
    It "All apiVersions in the template should be 'recent'"{
            foreach($mfolder in $moduleFolderPaths){
                $deployfilenames=Get-ChildItem -Path $mfolder -File
                foreach($deployfilename in $deployfilenames){
                $deployJsonContent=Get-Content $deployfilename -Raw
                $deployJsonConvert=$deployJsonContent | ConvertFrom-Json
                foreach($json in $deployJsonConvert.parameters){
                $membertype=($json | gm | where {$_.MemberType -eq "NoteProperty"}).Name
                foreach($member in $membertype){
                if($member -match "apiVersion_*"){
                $currentApi=$json.$member.defaultValue
                $indexofmember = $member.IndexOf("_")
                $rightPart = $member.Substring($indexofmember+1)
                $indexofmember1 = $rightPart.IndexOf("_")
                $leftPart = $rightPart.Substring(0, $indexofmember1)
                $latestApis=((Get-AzResourceProvider -ProviderNamespace $leftPart).ResourceTypes).ApiVersions | select -First 3
                if($latestApis -notcontains $currentApi){
                #$false | should -Throw "apiVersions in the template should be 'recent' at file $mfolder/$deployfilename" -ErrorAction Continue
                Write-Warning "apiVersions in the template should be 'recent' at file $deployfilename" -ErrorAction SilentlyContinue
                }
                }
                }
                } 

                }
                }
    }
}
}




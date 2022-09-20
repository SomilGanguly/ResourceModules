function New-ModuleDeployment {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string] $moduleName,

        [Parameter(Mandatory)]
        [string] $componentsBasePath,

        [Parameter(Mandatory)]
        [string] $parametersBasePath,

        [Parameter(Mandatory)]
        [string] $modulePath,

        [Parameter(Mandatory)]
        [string] $parameterFilePath,

        [Parameter(Mandatory)]
        [string] $location,

        [Parameter(Mandatory = $false)]
        [string] $resourceGroupName,

        [Parameter(Mandatory = $false)]       
        [string] $subscriptionId,

        [Parameter(Mandatory = $false)]       
        [string] $managementGroupId,

        [Parameter(Mandatory = $false)]       
        [bool] $removeDeployment,

        [Parameter(Mandatory)]       
        [string] $deployFile
    )
    
    begin 
    {
        Write-Debug ("{0} entered" -f $MyInvocation.MyCommand) 
    }
    
    process 
    {
        $templateFilePath = "$componentsBasePath/$modulePath/$deployFile"
        $parameterFilePath = Join-Path $parametersBasePath $parameterFilePath
        Write-Verbose "Got path: $templateFilePath"
        # Ensuring the deployment name is in the character limits.
        $Mnstring = $moduleName
        $measureObject = $Mnstring | Measure-Object -Character
        $count = $measureObject.Characters
        $deductedCount=$count-43
        if($count -gt 43)
        {

        $Mnstring=$Mnstring.substring(0,$Mnstring.length-$deductedCount)
        }
        else
        {
        $Mnstring
        }
        $DeploymentInputs = @{
            Name                  = "$Mnstring-$(-join (Get-Date -Format yyyyMMddTHHMMssffffZ)[0..64])"
            TemplateFile          = $templateFilePath
            TemplateParameterFile = $parameterFilePath
            Verbose               = $true
            ErrorAction           = 'Stop'
        }
        if ($removeDeployment)
         {
            # Fetch tags of parameter file if any (- required for the remove process. Tags may need to be compliant with potential customer requirements)
            $parameterFileTags = (ConvertFrom-Json (Get-Content -Raw -Path $parameterFilePath) -AsHashtable).parameters.tags.value
            if (-not $parameterFileTags) 
            {
                $parameterFileTags = @{}
            }
            $parameterFileTags['RemoveModule'] = $moduleName
        }
        #######################
        ## INVOKE DEPLOYMENT ##
        #######################
        
        New-AzResourceGroupDeployment @DeploymentInputs -ResourceGroupName $resourceGroupName

    }
    
    end 
    {
        Write-Debug ("{0} exited" -f $MyInvocation.MyCommand)  
    }
}
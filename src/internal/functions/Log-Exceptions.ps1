#  Description: This is an internal function to write and log exceptions. This function is called
#  internally whenever there is an exception raised from the internal code and is logged in a centralized log Json template per workload.

# Here's how you call the script:
# .\Log-Exceptions -ScriptName "SCRIPT NAME from where the error is getting generated" -LogPath "Path of the Central LOG Template" -Exception "INNER EXCEPTION" -Result "STATE" -ScriptPath "PATH of the error script"


function Log-Exceptions
    {
        param
        (
            [Parameter(Mandatory=$True)][string]$ScriptName,
            [string]$LogPath,
            [string]$Exception,
			[string]$Result,
			[string]$ScriptPath,
            [string]$branchName
        )
    
    $Time_Stamp = ($Time_Stamp = Get-Date).Datetime
  
	$NewLogData  = @{"Time" = $Time_stamp; "ScriptPath" = $ScriptPath; "Exception" = $Exception; "Result" = $Result; "Name" = $ScriptName}
    
	#Open Existing Log File to Get current data
	$CurrentLog = Get-Content -Path $LogPath -Raw | ConvertFrom-Json

	#If the log file is empty, CurrentLog cannot have a method called as it's 'Null Valued'.
	#Test for Null Value, if true, create CurrentLog as an Object 
    If($CurrentLog -eq $Null)
    {
        $CurrentLog = New-Object -TypeName PSObject
    }	
	
	#ScriptName is used as the top level key value. Should be a unique identifier
	#The value for this key is the data provided into the function when called
    $CurrentLog | Add-Member -Type NoteProperty -Name $ScriptName -Value $NewLogData
    
    $CurrentLog | ConvertTo-Json | Out-File $LogPath

    #redirect error
                $GIT_REDIRECT_STDERR = '2>&1'

                Write-Verbose "Setting git config...." -Verbose 

                git config --global user.email "azuredevops@microsoft.com"
                git config --global user.name "Azure DevOps"             

                git branch

                Write-Verbose "CHECK GIT STATUS..." -Verbose 
                git status

                Write-Verbose "git checkout...." -Verbose 
                git checkout -b $branchName

                Write-Verbose "git pull...." -Verbose 
                git pull origin $branchName

                Write-Verbose "GIT ADD..." -Verbose 
                git add $LogPath

                Write-Verbose "Commiting the changes..." -Verbose 
                git commit -m "Update from Build"

                Write-Verbose "Pushing the changes..." -Verbose 
                git push origin $branchName

                Write-Verbose "CHECK GIT STATUS..." -Verbose 
                git status
}


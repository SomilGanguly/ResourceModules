## This script is used to change the settings.json file to worklaod specific name.
## The changed filename will showup in relocationpull_n branches.

function Modify-SettingFileName {
    [CmdletBinding()]
    param (
        [string]
        $statePath = $pwd,
        [PSCustomObject]
        $workloadname
    )

    Rename-Item -Path "$statePath/utilities/tools/Carmlizer/src/Settings.json" -NewName $workloadname"_Settings.json"
    Write-Host 'Settings file has been updated based on the workload name'
    Get-ChildItem -Path "$statePath/src"
}

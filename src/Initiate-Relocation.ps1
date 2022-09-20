Import-Module .\src\internal\functions\Curated-ExportedARM.ps1 -Force
Import-Module .\src\internal\functions\Generate-ARMParameters.ps1 -Force
Import-Module .\src\internal\functions\DiscoverResources.ps1 -Force
Import-Module .\src\Functions\Get-Relocationpull.ps1 -Force
Import-Module .\src\internal\Functions\Dependencycopy.ps1 -Force

Get-Relocationpull -SubscriptionId ""
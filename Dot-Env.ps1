<#
.SYNOPSIS
Imports variables from an ENV file

.EXAMPLE
# Basic usage
dotenv

.EXAMPLE
# Provide a path
dotenv path/to/env

.EXAMPLE
# See what the command will do before it runs
dotenv -whatif

.EXAMPLE
# Create regular vars instead of env vars
dotenv -type regular
#>
function Dot-Env {
  [CmdletBinding(SupportsShouldProcess)]
  [Alias('dotenv')]
  param(
    [ValidateNotNullOrEmpty()]
    [String] $Path = '.env',

    # Determines whether variables are environment variables or normal
    [ValidateSet('Environment', 'Regular')]
    [String] $Type = 'Environment'
  )
  $Env = Get-Content -raw $Path | ConvertFrom-StringData
  $Env.GetEnumerator() | Foreach-Object {
    $Name, $Value = $_.Name, $_.Value
    if ($PSCmdlet.ShouldProcess($Name, "Importing $Type Variable")) {
      switch ($Type) {
        'Environment' { 
          Set-Content -Path "env:\$Name" -Value $Value
          Write-Host "Imported $Name as an environment variable. Value: $Value"
        }
        'Regular' { 
          Set-Variable -Name $Name -Value $Value -Scope Script
          Write-Host "Imported $Name as a regular variable. Value: $Value"
        }
      }
    }
  }
}

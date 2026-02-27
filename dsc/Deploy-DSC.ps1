<#
.SYNOPSIS
    Compiles and applies DSC configurations for Windows Server hardening and IIS setup.
.PARAMETER Mode
    Apply  - Compile MOFs and apply configurations (default)
    Test   - Only verify current state against DSC, no changes made
    CompileOnly - Compile MOFs without applying (CI syntax validation)
#>
param(
    [ValidateSet('Apply', 'Test', 'CompileOnly')]
    [string]$Mode = 'Apply'
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Dot-source configuration definitions
. "$scriptDir\HardeningConfig.ps1"
. "$scriptDir\IISConfig.ps1"

# Compile MOF files
Write-Host "::group::Compiling DSC configurations"
Write-Host "Compiling HardeningConfig..."
HardeningConfig -OutputPath "$scriptDir\HardeningConfig"

Write-Host "Compiling IISConfig..."
IISConfig -OutputPath "$scriptDir\IISConfig"
Write-Host "::endgroup::"

if ($Mode -eq 'CompileOnly') {
    Write-Host "MOF compilation succeeded — syntax is valid."
    exit 0
}

if ($Mode -eq 'Test') {
    Write-Host "::group::Testing DSC configuration state"
    $result = Test-DscConfiguration -Detailed
    Write-Host "::endgroup::"

    if ($result.InDesiredState) {
        Write-Host "All resources are in desired state."
        exit 0
    } else {
        Write-Host "::warning::Resources not in desired state:"
        $result.ResourcesNotInDesiredState | ForEach-Object {
            Write-Host "  - $($_.ResourceId)"
        }
        exit 1
    }
}

# Mode = Apply
Write-Host "::group::Applying HardeningConfig"
Start-DscConfiguration -Path "$scriptDir\HardeningConfig" -Wait -Force -Verbose
Write-Host "::endgroup::"

Write-Host "::group::Applying IISConfig"
Start-DscConfiguration -Path "$scriptDir\IISConfig" -Wait -Force -Verbose
Write-Host "::endgroup::"

Write-Host "::group::Verifying DSC state"
$result = Test-DscConfiguration -Detailed
Write-Host "::endgroup::"

if ($result.InDesiredState) {
    Write-Host "All resources are in desired state."
} else {
    Write-Host "::error::Resources NOT in desired state after apply:"
    $result.ResourcesNotInDesiredState | ForEach-Object {
        Write-Host "  - $($_.ResourceId)"
    }
    exit 1
}

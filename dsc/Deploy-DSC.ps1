<#
.SYNOPSIS
    Compiles and applies DSC configurations for Windows Server hardening and IIS.
.PARAMETER Mode
    Apply       - Compile MOFs and apply configurations (default)
    Test        - Only verify current state, no changes
    CompileOnly - Compile MOFs without applying (syntax validation)
#>
param(
    [ValidateSet('Apply', 'Test', 'CompileOnly')]
    [string]$Mode = 'Apply'
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$scriptDir\HardeningConfig.ps1"
. "$scriptDir\IISConfig.ps1"

Write-Host '::group::Compiling DSC configurations'
Write-Host 'Compiling HardeningConfig...'
HardeningConfig -OutputPath "$scriptDir\HardeningConfig"
Write-Host 'Compiling IISConfig...'
IISConfig -OutputPath "$scriptDir\IISConfig"
Write-Host '::endgroup::'

if ($Mode -eq 'CompileOnly') {
    Write-Host 'MOF compilation succeeded.'
    exit 0
}

if ($Mode -eq 'Test') {
    Write-Host '::group::Testing DSC configuration state'
    $result = Test-DscConfiguration -Detailed
    Write-Host '::endgroup::'
    if ($result.InDesiredState) {
        Write-Host 'All resources are in desired state.'
        exit 0
    }
    else {
        Write-Host '::warning::Resources not in desired state:'
        foreach ($r in $result.ResourcesNotInDesiredState) {
            Write-Host ('  - ' + $r.ResourceId)
        }
        exit 1
    }
}

Write-Host '::group::Applying HardeningConfig'
Start-DscConfiguration -Path "$scriptDir\HardeningConfig" -Wait -Force -Verbose
Write-Host '::endgroup::'

Write-Host '::group::Applying IISConfig'
Start-DscConfiguration -Path "$scriptDir\IISConfig" -Wait -Force -Verbose
Write-Host '::endgroup::'

Write-Host '::group::Verifying DSC state'
$result = Test-DscConfiguration -Detailed
Write-Host '::endgroup::'

if ($result.InDesiredState) {
    Write-Host 'All resources are in desired state.'
}
else {
    Write-Host '::error::Resources NOT in desired state after apply:'
    foreach ($r in $result.ResourcesNotInDesiredState) {
        Write-Host ('  - ' + $r.ResourceId)
    }
    exit 1
}

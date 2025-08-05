#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Installs the required Microsoft Graph PowerShell modules for the Graph API Usage script.

.DESCRIPTION
    This script installs the necessary Microsoft Graph PowerShell SDK modules required
    to run the Get-GraphAPIUsage.ps1 script.

.EXAMPLE
    .\Install-Prerequisites.ps1
#>

Write-Host "Installing Microsoft Graph PowerShell SDK Modules" -ForegroundColor Magenta
Write-Host "=" * 55 -ForegroundColor Magenta

$modules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Applications", 
    "Microsoft.Graph.Reports"
)

foreach ($module in $modules) {
    try {
        Write-Host "Checking if $module is installed..." -ForegroundColor Yellow
        
        $installed = Get-Module -ListAvailable -Name $module
        if ($installed) {
            Write-Host "$module is already installed (Version: $($installed[0].Version))" -ForegroundColor Green
        }
        else {
            Write-Host "Installing $module..." -ForegroundColor Cyan
            Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
            Write-Host "$module installed successfully!" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to install $module`: $($_.Exception.Message)"
    }
}

Write-Host "`nAll required modules have been processed." -ForegroundColor Magenta
Write-Host "You can now run the Get-GraphAPIUsage.ps1 script." -ForegroundColor Green

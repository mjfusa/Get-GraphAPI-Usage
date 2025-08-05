#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Applications, Microsoft.Graph.Reports

<#
.SYNOPSIS
    Generates a report of applications that call the Microsoft Graph API using the beta getApiUsage endpoint.

.DESCRIPTION
    This script connects to Microsoft Graph API, retrieves API usage data from the beta getApiUsage endpoint,
    looks up application names by their GUIDs, and outputs the data in CSV format with columns:
    Date, ServiceArea, TenantId, AppId, AppName, Usage

.PARAMETER OutputPath
    The path where the CSV report will be saved. If not specified, outputs to console.

.PARAMETER Days
    Number of days to look back for usage data. Default is 30 days.

.EXAMPLE
    .\Get-GraphAPIUsage.ps1
    
.EXAMPLE
    .\Get-GraphAPIUsage.ps1 -OutputPath "C:\Reports\GraphAPIUsage.csv" -Days 7
#>

param(
    [string]$OutputPath,
    [int]$Days = 30
)

# Function to connect to Microsoft Graph
function Connect-ToGraph {
    try {
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
        
        # Connect with required scopes
        $requiredScopes = @(
            "Reports.Read.All",
            "Application.Read.All",
            "Directory.Read.All"
        )
        
        Connect-MgGraph -Scopes $requiredScopes -NoWelcome
        Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
        exit 1
    }
}

# Function to get application name by AppId
function Get-ApplicationName {
    param([string]$AppId)
    
    try {
        # Try to get the application from Azure AD
        $app = Get-MgApplication -Filter "appId eq '$AppId'" -ErrorAction SilentlyContinue
        if ($app) {
            return $app.DisplayName
        }
        
        # If not found in applications, try service principals
        $servicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$AppId'" -ErrorAction SilentlyContinue
        if ($servicePrincipal) {
            return $servicePrincipal.DisplayName
        }
        
        # If still not found, return the AppId itself
        return $AppId
    }
    catch {
        Write-Warning "Could not retrieve name for AppId: $AppId. Error: $($_.Exception.Message)"
        return $AppId
    }
}

# Function to get API usage data
function Get-APIUsageData {
    param([int]$Days)
    
    try {
        Write-Host "Retrieving API usage data for the last $Days days..." -ForegroundColor Yellow
        
        # Calculate date range
        $endDate = Get-Date
        $startDate = $endDate.AddDays(-$Days)
        
        # Format dates for the API call
        $startDateString = $startDate.ToString("yyyy-MM-dd")
        $endDateString = $endDate.ToString("yyyy-MM-dd")
        
        # Construct the URI for the beta getApiUsage endpoint
        $uri = "https://graph.microsoft.com/beta/reports/getApiUsage(period='D$Days')"
        
        Write-Host "Querying: $uri" -ForegroundColor Cyan
        
        # Make the API call - getApiUsage returns CSV data
        $tempFile = Join-Path $env:TEMP "graphapi_usage_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        Invoke-MgGraphRequest -Uri $uri -Method GET -OutputFilePath $tempFile
        
        # Check if file exists and has content
        if (Test-Path $tempFile) {
            try {
                $csvContent = Import-Csv -Path $tempFile
                
                # Clean up temp file
                # Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
                
                if ($csvContent -and $csvContent.Count -gt 0) {
                    Write-Host "Retrieved $($csvContent.Count) usage records" -ForegroundColor Green
                    return $csvContent
                }
                else {
                    Write-Warning "CSV file exists but contains no data for the specified period"
                    return @()
                }
            }
            catch {
                Write-Error "Failed to parse CSV response: $($_.Exception.Message)"
                # Clean up temp file on error
                # Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
                return @()
            }
        }
        else {
            Write-Warning "No data file was created - no usage data found for the specified period"
            return @()
        }
    }
    catch {
        Write-Error "Failed to retrieve API usage data: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            Write-Error "Response: $($_.Exception.Response)"
        }
        return @()
    }
}

# Function to process and format the data
function Process-UsageData {
    param($UsageData)
    
    Write-Host "Processing usage data and looking up application names..." -ForegroundColor Yellow
    
    # Display CSV column information for debugging
    if ($UsageData -and $UsageData.Count -gt 0) {
        $columns = $UsageData[0].PSObject.Properties.Name
        Write-Host "CSV Columns found: $($columns -join ', ')" -ForegroundColor Cyan
    }
    
    $processedData = @()
    $appNameCache = @{}
    
    foreach ($record in $UsageData) {
        # Extract AppId using proper null-coalescing approach
        $appId = if ($record.PSObject.Properties['appId'] -and ![string]::IsNullOrWhiteSpace($record.appId)) { $record.appId }
                 elseif ($record.PSObject.Properties['AppId'] -and ![string]::IsNullOrWhiteSpace($record.AppId)) { $record.AppId }
                 elseif ($record.PSObject.Properties['App ID'] -and ![string]::IsNullOrWhiteSpace($record.'App ID')) { $record.'App ID' }
                 elseif ($record.PSObject.Properties['ApplicationId'] -and ![string]::IsNullOrWhiteSpace($record.ApplicationId)) { $record.ApplicationId }
                 else { $null }
        
        # Skip records without a valid AppId
        if ([string]::IsNullOrWhiteSpace($appId)) {
            Write-Warning "Skipping record with no valid AppId"
            continue
        }
        
        # Cache application names to avoid repeated API calls
        if (-not $appNameCache.ContainsKey($appId)) {
            Write-Host "Looking up name for AppId: $appId" -ForegroundColor Cyan
            $appNameCache[$appId] = Get-ApplicationName -AppId $appId
        }
        
        # Apply same approach to other fields with proper null/empty string handling
        $date = if ($record.PSObject.Properties['reportDate'] -and ![string]::IsNullOrWhiteSpace($record.reportDate)) { $record.reportDate }
                elseif ($record.PSObject.Properties['ReportDate'] -and ![string]::IsNullOrWhiteSpace($record.ReportDate)) { $record.ReportDate }
                elseif ($record.PSObject.Properties['Report Date'] -and ![string]::IsNullOrWhiteSpace($record.'Report Date')) { $record.'Report Date' }
                elseif ($record.PSObject.Properties['Date'] -and ![string]::IsNullOrWhiteSpace($record.Date)) { $record.Date }
                else { $null }
        
        $serviceArea = if ($record.PSObject.Properties['serviceArea'] -and ![string]::IsNullOrWhiteSpace($record.serviceArea)) { $record.serviceArea }
                       elseif ($record.PSObject.Properties['ServiceArea'] -and ![string]::IsNullOrWhiteSpace($record.ServiceArea)) { $record.ServiceArea }
                       elseif ($record.PSObject.Properties['Service Area'] -and ![string]::IsNullOrWhiteSpace($record.'Service Area')) { $record.'Service Area' }
                       else { $null }
        
        $tenantId = if ($record.PSObject.Properties['tenantId'] -and ![string]::IsNullOrWhiteSpace($record.tenantId)) { $record.tenantId }
                    elseif ($record.PSObject.Properties['TenantId'] -and ![string]::IsNullOrWhiteSpace($record.TenantId)) { $record.TenantId }
                    elseif ($record.PSObject.Properties['Tenant ID'] -and ![string]::IsNullOrWhiteSpace($record.'Tenant ID')) { $record.'Tenant ID' }
                    else { $null }
        
        # For usage count, handle both string and numeric values
        $usage = if ($record.PSObject.Properties['requestCount'] -and $record.requestCount -ne $null -and $record.requestCount -ne '') { 
                     try { [int]$record.requestCount } catch { 0 }
                 }
                 elseif ($record.PSObject.Properties['RequestCount'] -and $record.RequestCount -ne $null -and $record.RequestCount -ne '') { 
                     try { [int]$record.RequestCount } catch { 0 }
                 }
                 elseif ($record.PSObject.Properties['Request Count'] -and $record.'Request Count' -ne $null -and $record.'Request Count' -ne '') { 
                     try { [int]$record.'Request Count' } catch { 0 }
                 }
                 elseif ($record.PSObject.Properties['Usage'] -and $record.Usage -ne $null -and $record.Usage -ne '') { 
                     try { [int]$record.Usage } catch { 0 }
                 }
                 elseif ($record.PSObject.Properties['Count'] -and $record.Count -ne $null -and $record.Count -ne '') { 
                     try { [int]$record.Count } catch { 0 }
                 }
                 else { 0 }
        
        $processedRecord = [PSCustomObject]@{
            Date = $date
            ServiceArea = $serviceArea
            TenantId = $tenantId
            AppId = $appId
            AppName = $appNameCache[$appId]
            Usage = $usage
        }
        
        $processedData += $processedRecord
    }
    
    return $processedData
}

# Main execution
try {
    Write-Host "Starting Microsoft Graph API Usage Report Generation" -ForegroundColor Magenta
    Write-Host "=" * 60 -ForegroundColor Magenta
    
    # Connect to Graph
    Connect-ToGraph
    
    # Get current context
    $context = Get-MgContext
    Write-Host "Connected as: $($context.Account)" -ForegroundColor Green
    Write-Host "Tenant: $($context.TenantId)" -ForegroundColor Green
    
    # Get API usage data
    $usageData = Get-APIUsageData -Days $Days
    
    if ($usageData.Count -eq 0) {
        Write-Warning "No usage data to process. Exiting."
        exit 0
    }
    
    # Process the data
    $reportData = Process-UsageData -UsageData $usageData
    
    # Output the results
    if ($OutputPath) {
        Write-Host "Saving report to: $OutputPath" -ForegroundColor Yellow
        $reportData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Host "Report saved successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "Displaying report data:" -ForegroundColor Yellow
        $reportData | Format-Table -AutoSize
    }
    
    Write-Host "`nReport Summary:" -ForegroundColor Magenta
    Write-Host "Total records: $($reportData.Count)" -ForegroundColor White
    Write-Host "Unique applications: $($reportData | Select-Object -Unique AppId | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor White
    Write-Host "Date range: $($reportData | Measure-Object Date -Minimum -Maximum | ForEach-Object { "$($_.Minimum) to $($_.Maximum)" })" -ForegroundColor White
    
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    Write-Error $_.ScriptStackTrace
}
finally {
    # Disconnect from Graph
    try {
        $DisconnectInfo = Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Host "Disconnected from Microsoft Graph" -ForegroundColor Yellow
    }
    catch {
        # Ignore disconnect errors
    }
}

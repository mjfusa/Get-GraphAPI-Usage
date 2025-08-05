#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Reports

<#
.SYNOPSIS
    Test script to examine the structure of the getApiUsage CSV response.

.DESCRIPTION
    This script connects to Microsoft Graph API and retrieves a small sample of API usage data
    to examine the CSV structure and column names returned by the getApiUsage endpoint.

.EXAMPLE
    .\Test-GetApiUsageStructure.ps1
#>

try {
    Write-Host "Testing Microsoft Graph API Usage CSV Structure" -ForegroundColor Magenta
    Write-Host "=" * 50 -ForegroundColor Magenta
    
    # Connect with minimal required scope
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Reports.Read.All" -NoWelcome
    Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
    
    # Test with 1 day to minimize data returned
    $uri = "https://graph.microsoft.com/beta/reports/getApiUsage(period='D1')"
    Write-Host "Querying: $uri" -ForegroundColor Cyan
    
    # Make the API call
    $tempFile = Join-Path $env:TEMP "test_graphapi_usage_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    Invoke-MgGraphRequest -Uri $uri -Method GET -OutputFilePath $tempFile
    
    # Examine the CSV structure
    if (Test-Path $tempFile) {
        Write-Host "CSV file created successfully at: $tempFile" -ForegroundColor Green
        
        # Show first few lines of raw CSV
        Write-Host "`nFirst 5 lines of raw CSV:" -ForegroundColor Yellow
        Get-Content $tempFile | Select-Object -First 5 | ForEach-Object { Write-Host $_ }
        
        # Import and examine structure
        $csvData = Import-Csv -Path $tempFile
        
        if ($csvData -and $csvData.Count -gt 0) {
            Write-Host "`nCSV imported successfully. Record count: $($csvData.Count)" -ForegroundColor Green
            
            # Show column names
            $columns = $csvData[0].PSObject.Properties.Name
            Write-Host "`nColumn names found:" -ForegroundColor Yellow
            $columns | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
            
            # Show sample data (first record)
            Write-Host "`nSample record (first row):" -ForegroundColor Yellow
            $csvData[0].PSObject.Properties | ForEach-Object {
                Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor White
            }
            
            # Show unique service areas if available
            $serviceAreaColumn = $columns | Where-Object { $_ -match "service|area" } | Select-Object -First 1
            if ($serviceAreaColumn) {
                $uniqueServiceAreas = $csvData | Select-Object -Property $serviceAreaColumn -Unique | Select-Object -First 10
                Write-Host "`nUnique Service Areas (first 10):" -ForegroundColor Yellow
                $uniqueServiceAreas | ForEach-Object { Write-Host "  - $($_.$serviceAreaColumn)" -ForegroundColor White }
            }
        }
        else {
            Write-Host "No data found in CSV or CSV is empty" -ForegroundColor Red
        }
        
        # Clean up
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "No CSV file was created" -ForegroundColor Red
    }
}
catch {
    Write-Error "Test failed: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Host "Response details: $($_.Exception.Response)" -ForegroundColor Red
    }
}
finally {
    # Disconnect from Graph
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Host "`nDisconnected from Microsoft Graph" -ForegroundColor Yellow
    }
    catch {
        # Ignore disconnect errors
    }
}

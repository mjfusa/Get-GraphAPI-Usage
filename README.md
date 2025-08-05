# Microsoft Graph API Usage Report Script

This PowerShell script generates a comprehensive report of applications that call the Microsoft Graph API using the beta `getApiUsage` endpoint. It retrieves usage data and looks up application names by their GUIDs.

## Prerequisites

1. **PowerShell 5.1 or PowerShell 7+**
2. **Microsoft Graph PowerShell SDK modules:**
   ```powershell
   Install-Module Microsoft.Graph.Authentication -Force
   Install-Module Microsoft.Graph.Applications -Force
   Install-Module Microsoft.Graph.Reports -Force
   ```

## Required Permissions

The script requires the following Microsoft Graph API permissions:
- `Reports.Read.All` - To read usage reports
- `Application.Read.All` - To read application information
- `Directory.Read.All` - To read directory objects

## Usage

### Basic Usage (Console Output)
```powershell
.\Get-GraphAPIUsage.ps1
```

### Save to CSV File
```powershell
.\Get-GraphAPIUsage.ps1 -OutputPath "C:\Reports\GraphAPIUsage.csv"
```

### Specify Time Period (7 days)
```powershell
.\Get-GraphAPIUsage.ps1 -Days 7 -OutputPath "C:\Reports\GraphAPIUsage.csv"
```

## Output Format

The script generates data with the following columns:
- **Date** - The date of the usage record
- **ServiceArea** - The Microsoft Graph service area
- **TenantId** - The tenant identifier
- **AppId** - The application identifier (GUID)
- **AppName** - The display name of the application
- **Usage** - The number of API requests

## Authentication

The script will prompt for authentication when run. You need to sign in with an account that has the required permissions to read reports and application information.

## Features

- **CSV Data Handling**: Properly handles CSV response from the getApiUsage endpoint
- **Application Name Lookup**: Automatically resolves application GUIDs to display names
- **Flexible Column Mapping**: Handles different CSV column name variations
- **Caching**: Caches application names to minimize API calls
- **Error Handling**: Robust error handling with informative messages
- **Flexible Output**: Console display or CSV file export
- **Summary Statistics**: Displays summary information about the report
- **Debug Information**: Shows CSV structure for troubleshooting

## Testing CSV Structure

If you want to examine the CSV structure returned by the API before running the full report:

```powershell
.\Test-GetApiUsageStructure.ps1
```

This test script will show you the column names and structure of the CSV data returned by the getApiUsage endpoint.

## Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure your account has the required Graph API permissions
2. **Module Not Found**: Install the required Microsoft Graph PowerShell modules
3. **API Limits**: The script includes built-in delays to respect API rate limits

### Error Messages

- `Failed to connect to Microsoft Graph`: Check your internet connection and credentials
- `No usage data found`: The specified time period may not have any API usage data
- `Could not retrieve name for AppId`: The application may no longer exist or you may lack permissions

## Notes

- The script uses the beta Graph API endpoint for usage data
- Application names are cached during execution to improve performance
- If an application name cannot be resolved, the AppId is used instead
- The script automatically disconnects from Microsoft Graph when completed

## Example Output

```
Date        ServiceArea    TenantId                              AppId                                 AppName              Usage
----        -----------    --------                              -----                                 -------              -----
2025-08-04  Microsoft365   12345678-1234-1234-1234-123456789012 87654321-4321-4321-4321-210987654321 MyCustomApp          150
2025-08-04  AzureAD        12345678-1234-1234-1234-123456789012 11111111-2222-3333-4444-555555555555 PowerBI              75
```

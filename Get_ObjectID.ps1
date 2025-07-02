<#
.SYNOPSIS
Retrieves Azure AD device Object IDs from Microsoft Graph based on device display names.

.DESCRIPTION
This script connects to Microsoft Graph and retrieves Object IDs for Azure AD devices.
It supports both single device lookups (output to console) and bulk operations from 
a text file (output to CSV). The script will prompt for input method if no parameters
are provided.

.PARAMETER DeviceName
Single device display name to lookup. When provided, results are displayed on screen.

.PARAMETER InputFilePath
Path to a text file containing device display names (one per line). When provided,
results are exported to a CSV file.

.PARAMETER OutputFilePath
Path for the output CSV file when processing multiple devices. Defaults to 
"C:\Temp\DeviceObjectIDs.csv" if not specified.

.EXAMPLE
.\Get-ObjectID.ps1 -DeviceName "DESKTOP-ABC123"
Retrieves Object ID for a single device and displays it on screen.

.EXAMPLE
.\Get-ObjectID.ps1 -InputFilePath "C:\temp\hostnames.txt"
Processes multiple devices from file and exports results to CSV.

.EXAMPLE
.\Get-ObjectID.ps1 -InputFilePath "C:\temp\hostnames.txt" -OutputFilePath "C:\temp\results.csv"
Processes multiple devices with custom output file path.

.NOTES
Author: 8bits1beard
Date: 2025-01-27
Version: v1.0.0
Source: ../PoSh-Best-Practice/ or ../PoSh-style/

.LINK
../PoSh-Best-Practice/
#>

[CmdletBinding(DefaultParameterSetName = 'Interactive')]
param(
    # Single device display name for lookup
    [Parameter(ParameterSetName = 'SingleDevice', Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DeviceName,
    
    # Path to input file containing device names
    [Parameter(ParameterSetName = 'BulkOperation', Mandatory = $true)]
    [ValidateScript({
        if (Test-Path -Path $_ -PathType Leaf) {
            $true
        } else {
            throw "Input file not found: $_"
        }
    })]
    [string]$InputFilePath,
    
    # Path for output CSV file (bulk operations only)
    [Parameter(ParameterSetName = 'BulkOperation')]
    [string]$OutputFilePath = "C:\Temp\DeviceObjectIDs.csv"
)

function Test-MicrosoftGraphModule {
    <#
    .SYNOPSIS
    Checks if Microsoft.Graph module is installed and installs it if missing.
    #>
    
    # Check if the Microsoft.Graph module is available
    if (Get-Module -ListAvailable -Name "Microsoft.Graph") {
        Write-Information "Microsoft.Graph module found" -InformationAction Continue
        return $true
    } else {
        Write-Warning "Microsoft.Graph module not found. Installing..."
        try {
            # Install the module from PowerShell Gallery
            Install-Module Microsoft.Graph -Repository PSGallery -Force -AllowClobber
            Write-Information "Microsoft.Graph module installed successfully" -InformationAction Continue
            return $true
        } catch {
            Write-Error "Failed to install Microsoft.Graph module: $($_.Exception.Message)"
            return $false
        }
    }
}

function Connect-ToMicrosoftGraph {
    <#
    .SYNOPSIS
    Establishes connection to Microsoft Graph with appropriate scopes.
    #>
    
    try {
        # Connect to Microsoft Graph with required scopes for device management
        Connect-MgGraph -Scopes "Device.Read.All"
        Write-Information "Successfully connected to Microsoft Graph" -InformationAction Continue
    } catch {
        Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
        throw
    }
}

function Get-DeviceObjectID {
    <#
    .SYNOPSIS
    Retrieves Object ID for a single device by display name.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )
    
    try {
        # Query Microsoft Graph for device by display name
        $device = Get-MgDevice -Filter "displayName eq '$DisplayName'"
        
        if ($device) {
            return [PSCustomObject]@{
                DisplayName = $DisplayName
                ObjectID = $device.Id
                Status = "Found"
            }
        } else {
            return [PSCustomObject]@{
                DisplayName = $DisplayName
                ObjectID = $null
                Status = "Not Found"
            }
        }
    } catch {
        Write-Warning "Error retrieving device '$DisplayName': $($_.Exception.Message)"
        return [PSCustomObject]@{
            DisplayName = $DisplayName
            ObjectID = $null
            Status = "Error: $($_.Exception.Message)"
        }
    }
}

function Get-UserInputChoice {
    <#
    .SYNOPSIS
    Prompts user to choose between single device or bulk operation.
    #>
    
    Write-Host "`n=== Device Object ID Lookup Tool ===" -ForegroundColor Cyan
    Write-Host "Please choose an option:" -ForegroundColor Yellow
    Write-Host "1. Single device lookup (display results on screen)" -ForegroundColor Green
    Write-Host "2. Bulk operation from file (export to CSV)" -ForegroundColor Green
    
    do {
        $choice = Read-Host "`nEnter your choice (1 or 2)"
    } while ($choice -notin @('1', '2'))
    
    return $choice
}

# Main script execution begins here
try {
    # Ensure Microsoft.Graph module is available
    if (-not (Test-MicrosoftGraphModule)) {
        throw "Microsoft.Graph module is required but could not be installed."
    }
    
    # Connect to Microsoft Graph
    Connect-ToMicrosoftGraph
    
    # Determine operation mode based on parameters or user input
    if ($PSCmdlet.ParameterSetName -eq 'Interactive') {
        # Interactive mode - prompt user for choice
        $userChoice = Get-UserInputChoice
        
        if ($userChoice -eq '1') {
            # Single device mode
            do {
                $deviceName = Read-Host "`nEnter device display name"
            } while ([string]::IsNullOrWhiteSpace($deviceName))
            
            Write-Host "`nLooking up device: $deviceName" -ForegroundColor Yellow
            
            # Retrieve and display single device information
            $result = Get-DeviceObjectID -DisplayName $deviceName
            
            Write-Host "`n=== Results ===" -ForegroundColor Cyan
            Write-Host "Device Name: $($result.DisplayName)" -ForegroundColor White
            Write-Host "Object ID: $($result.ObjectID)" -ForegroundColor White
            Write-Host "Status: $($result.Status)" -ForegroundColor White
            
        } else {
            # Bulk operation mode
            do {
                $inputFile = Read-Host "`nEnter path to input file containing device names"
            } while ([string]::IsNullOrWhiteSpace($inputFile) -or -not (Test-Path -Path $inputFile))
            
            $outputFile = Read-Host "Enter output CSV file path (press Enter for default: C:\Temp\DeviceObjectIDs.csv)"
            if ([string]::IsNullOrWhiteSpace($outputFile)) {
                $outputFile = "C:\Temp\DeviceObjectIDs.csv"
            }
            
            # Process bulk operation
            $InputFilePath = $inputFile
            $OutputFilePath = $outputFile
        }
    }
    
    # Execute bulk operation if InputFilePath is set
    if ($InputFilePath) {
        Write-Host "`nProcessing devices from file: $InputFilePath" -ForegroundColor Yellow
        
        # Read device names from input file
        $deviceNames = Get-Content -Path $InputFilePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        
        if ($deviceNames.Count -eq 0) {
            throw "No valid device names found in input file."
        }
        
        Write-Host "Found $($deviceNames.Count) device(s) to process" -ForegroundColor Green
        
        # Create output directory if it doesn't exist
        $outputDir = Split-Path -Path $OutputFilePath -Parent
        if (-not (Test-Path -Path $outputDir)) {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        }
        
        # Process each device and collect results
        $results = @()
        $counter = 0
        
        foreach ($deviceName in $deviceNames) {
            $counter++
            Write-Progress -Activity "Processing Devices" -Status "Processing $deviceName" -PercentComplete (($counter / $deviceNames.Count) * 100)
            
            # Get Object ID for current device
            $result = Get-DeviceObjectID -DisplayName $deviceName.Trim()
            $results += $result
        }
        
        # Export results to CSV
        $results | Export-Csv -Path $OutputFilePath -NoTypeInformation -Encoding UTF8
        
        Write-Host "`nProcessing complete!" -ForegroundColor Green
        Write-Host "Results exported to: $OutputFilePath" -ForegroundColor Cyan
        
        # Display summary
        $foundCount = ($results | Where-Object { $_.Status -eq "Found" }).Count
        $notFoundCount = ($results | Where-Object { $_.Status -eq "Not Found" }).Count
        $errorCount = ($results | Where-Object { $_.Status -like "Error:*" }).Count
        
        Write-Host "`n=== Summary ===" -ForegroundColor Cyan
        Write-Host "Total devices processed: $($results.Count)" -ForegroundColor White
        Write-Host "Found: $foundCount" -ForegroundColor Green
        Write-Host "Not found: $notFoundCount" -ForegroundColor Yellow
        Write-Host "Errors: $errorCount" -ForegroundColor Red
    }
    
} catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
} finally {
    # Cleanup - disconnect from Microsoft Graph
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Information "Disconnected from Microsoft Graph" -InformationAction Continue
    } catch {
        # Ignore disconnect errors
    }
}
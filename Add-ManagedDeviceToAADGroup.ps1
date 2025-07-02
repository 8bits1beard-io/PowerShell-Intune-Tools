<#
.SYNOPSIS
Adds Microsoft Intune managed devices to Azure Active Directory security groups.

.DESCRIPTION
This script provides an interactive workflow to add Intune managed devices to Azure AD security groups.
It can query devices by associated user UPN, device name, or work with device IDs directly.
The script identifies appropriate security groups and adds the selected device to the group.
It includes comprehensive error handling and validation to ensure only appropriate groups are targeted.

.PARAMETER UserPrincipalName
The User Principal Name (UPN) of the device owner to filter managed devices.
Used to narrow down device selection when multiple devices exist in the tenant.

.PARAMETER DeviceName
The display name of the specific managed device to add to the group.
Alternative to using UserPrincipalName for device selection.

.PARAMETER DeviceId
The Intune Device ID of the specific device to add to the group.
When not provided, the script will display available devices and prompt for selection.

.PARAMETER GroupName
The display name of the Azure AD security group to add the device to.
When not provided, the script will prompt for input and display matching groups.

.EXAMPLE
.\Add-ManagedDeviceToAADGroup.ps1
Runs the script in interactive mode, prompting for all required inputs.

.EXAMPLE
.\Add-ManagedDeviceToAADGroup.ps1 -UserPrincipalName "user@contoso.com"
Queries devices assigned to the specified user and prompts for device and group selection.

.EXAMPLE
.\Add-ManagedDeviceToAADGroup.ps1 -DeviceName "DESKTOP-ABC123"
Queries for the specific device name and prompts for group selection.

.EXAMPLE
.\Add-ManagedDeviceToAADGroup.ps1 -DeviceId "12345678-1234-1234-1234-123456789012" -GroupName "Security-Devices"
Adds the specified device to the specified group with minimal prompting.

.INPUTS
System.String
User Principal Name, Device Name, Device ID, and Group Name can be provided as parameters.

.OUTPUTS
System.String
Status messages indicating success or failure of the group membership addition.

.NOTES
Author: 8bits1beard
Date: 2025-07-02
Version: v1.0.0
Source: ../PoSh-Best-Practice/ or ../PoSh-style/

Requires the following Microsoft Graph PowerShell modules:
- Microsoft.Graph.Groups
- Microsoft.Graph.DeviceManagement  
- Microsoft.Graph.Identity.DirectoryManagement

Required permissions:
- DeviceManagementManagedDevices.Read.All
- Device.Read.All
- Group.ReadWrite.All

.LINK
../PoSh-Best-Practice/
#>

[CmdletBinding(DefaultParameterSetName = 'Interactive')]
param(
    # User Principal Name to filter managed devices by device owner
    [Parameter(ParameterSetName = 'ByUser', HelpMessage = "Enter the User Principal Name (UPN) of the device owner to filter managed devices")]
    [Parameter(ParameterSetName = 'Interactive', HelpMessage = "Enter the User Principal Name (UPN) of the device owner to filter managed devices")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")]
    [string]$UserPrincipalName,
    
    # Device display name to search for specific device
    [Parameter(ParameterSetName = 'ByDeviceName', HelpMessage = "Enter the display name of the managed device")]
    [ValidateNotNullOrEmpty()]
    [string]$DeviceName,
    
    # Intune Device ID to add to the group
    [Parameter(ParameterSetName = 'ByDeviceId', Mandatory = $true, HelpMessage = "Enter the Intune Device ID (GUID) of the device to add to the group")]
    [ValidateNotNullOrEmpty()]
    [string]$DeviceId,
    
    # Azure AD Group Name to add the device to
    [Parameter(HelpMessage = "Enter the display name of the Azure AD security group")]
    [ValidateNotNullOrEmpty()]
    [string]$GroupName
)

function Test-RequiredModules {
    <#
    .SYNOPSIS
    Validates that required Microsoft Graph modules are available.
    
    .DESCRIPTION
    Checks for the presence of required Microsoft Graph PowerShell modules
    and provides guidance if any are missing.
    #>
    
    # Define required modules for this script
    $requiredModules = @(
        'Microsoft.Graph.Groups',
        'Microsoft.Graph.DeviceManagement',
        'Microsoft.Graph.Identity.DirectoryManagement'
    )
    
    $missingModules = @()
    
    # Check each required module
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            $missingModules += $module
        }
    }
    
    # Report missing modules and exit if any are found
    if ($missingModules.Count -gt 0) {
        Write-Error "Missing required modules: $($missingModules -join ', ')"
        Write-Information "Install missing modules using: Install-Module $($missingModules -join ', ')" -InformationAction Continue
        return $false
    }
    
    return $true
}

function Import-RequiredModules {
    <#
    .SYNOPSIS
    Imports required Microsoft Graph modules with error handling.
    
    .DESCRIPTION
    Safely imports the Microsoft Graph modules required for device and group operations.
    #>
    
    try {
        # Import required Graph modules
        Import-Module Microsoft.Graph.Groups -ErrorAction Stop
        Import-Module Microsoft.Graph.DeviceManagement -ErrorAction Stop  
        Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop
        
        Write-Verbose "Successfully imported required Microsoft Graph modules"
    }
    catch {
        Write-Error "Failed to import required modules: $($_.Exception.Message)"
        throw
    }
}

function Get-ManagedDevicesByUser {
    <#
    .SYNOPSIS
    Retrieves Intune managed devices for a specified device owner.
    
    .DESCRIPTION
    Queries Microsoft Graph to retrieve all managed devices associated with a user's UPN.
    The UserPrincipalName represents the primary user/owner of the device in Intune.
    
    .PARAMETER UserPrincipalName
    The User Principal Name of the device owner to query devices for.
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$UserPrincipalName
    )
    
    try {
        # Escape single quotes in UPN to prevent OData filter injection
        $escapedUPN = $UserPrincipalName -replace "'", "''"
        
        Write-Verbose "Querying managed devices owned by user: $UserPrincipalName"
        
        # Query Intune for managed devices where the specified user is the primary user/owner
        $devices = Get-MgDeviceManagementManagedDevice -Filter "UserPrincipalName eq '$escapedUPN'" | 
            Select-Object ManagedDeviceName, Id, DeviceName, Manufacturer, AzureAdDeviceId, UserPrincipalName, UserId
        
        if ($null -eq $devices -or $devices.Count -eq 0) {
            Write-Warning "No managed devices found for device owner: $UserPrincipalName"
            return $null
        }
        
        Write-Information "Found $($devices.Count) managed device(s) owned by user: $UserPrincipalName" -InformationAction Continue
        return $devices
    }
    catch {
        Write-Error "Failed to retrieve managed devices for device owner '$UserPrincipalName': $($_.Exception.Message)"
        throw
    }
}

function Get-ManagedDevicesByName {
    <#
    .SYNOPSIS
    Retrieves Intune managed devices by device display name.
    
    .DESCRIPTION
    Queries Microsoft Graph to retrieve managed devices that match the specified device name.
    Supports partial matching to handle cases where exact device names are unknown.
    
    .PARAMETER DeviceName
    The display name or partial name of the device to search for.
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName
    )
    
    try {
        Write-Verbose "Querying managed devices with name containing: $DeviceName"
        
        # Query Intune for managed devices with names containing the search term
        $devices = Get-MgDeviceManagementManagedDevice -Filter "contains(deviceName,'$DeviceName')" | 
            Select-Object ManagedDeviceName, Id, DeviceName, Manufacturer, AzureAdDeviceId, UserPrincipalName, UserId
        
        if ($null -eq $devices -or $devices.Count -eq 0) {
            Write-Warning "No managed devices found with name containing: $DeviceName"
            return $null
        }
        
        Write-Information "Found $($devices.Count) managed device(s) matching name: $DeviceName" -InformationAction Continue
        return $devices
    }
    catch {
        Write-Error "Failed to retrieve managed devices with name '$DeviceName': $($_.Exception.Message)"
        throw
    }
}

function Get-AzureADObjectIdFromDevice {
    <#
    .SYNOPSIS
    Retrieves Azure AD Object ID from an Intune device's Azure AD Device ID.
    
    .DESCRIPTION
    Translates between Intune device identifiers and Azure AD Object IDs by querying
    Azure AD using the device's Azure AD Device ID.
    
    .PARAMETER AzureAdDeviceId
    The Azure AD Device ID from the Intune managed device record.
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AzureAdDeviceId
    )
    
    try {
        Write-Verbose "Retrieving Azure AD Object ID for device: $AzureAdDeviceId"
        
        # Query Azure AD for the device using its Device ID to get the Object ID
        $azureAdDevice = Get-MgDevice -Filter "DeviceId eq '$AzureAdDeviceId'"
        
        if ($null -eq $azureAdDevice) {
            Write-Warning "No Azure AD Object ID found for device: $AzureAdDeviceId"
            return $null
        }
        
        Write-Verbose "Found Azure AD Object ID: $($azureAdDevice.Id)"
        return $azureAdDevice.Id
    }
    catch {
        Write-Error "Failed to retrieve Azure AD Object ID for device '$AzureAdDeviceId': $($_.Exception.Message)"
        throw
    }
}

function Get-EligibleSecurityGroups {
    <#
    .SYNOPSIS
    Retrieves Azure AD security groups eligible for device membership.
    
    .DESCRIPTION
    Searches for Azure AD groups by display name and filters to only include
    security-enabled, non-mail-enabled, static membership groups that can accept device members.
    
    .PARAMETER GroupName
    The display name to search for in Azure AD groups.
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$GroupName
    )
    
    try {
        Write-Verbose "Searching for security groups with name: $GroupName"
        
        # Query Azure AD for groups matching the display name
        $groups = Get-MgGroup -Filter "DisplayName eq '$GroupName'" | 
            Select-Object DisplayName, Id, Description, GroupTypes, Mail, MailEnabled, SecurityEnabled
        
        if ($null -eq $groups -or $groups.Count -eq 0) {
            Write-Warning "No groups found with name: $GroupName"
            return $null
        }
        
        # Filter to only include security-enabled, non-mail-enabled, static groups
        $eligibleGroups = $groups | Where-Object { 
            $_.SecurityEnabled -eq $true -and 
            $_.MailEnabled -eq $false -and 
            $_.GroupTypes -notcontains 'DynamicMembership' 
        }
        
        if ($null -eq $eligibleGroups -or $eligibleGroups.Count -eq 0) {
            Write-Warning "No eligible security groups found with name: $GroupName"
            Write-Information "Groups must be security-enabled, not mail-enabled, and have static membership" -InformationAction Continue
            return $null
        }
        
        Write-Information "Found $($eligibleGroups.Count) eligible security group(s)" -InformationAction Continue
        return $eligibleGroups
    }
    catch {
        Write-Error "Failed to retrieve security groups for '$GroupName': $($_.Exception.Message)"
        throw
    }
}

function Add-DeviceToSecurityGroup {
    <#
    .SYNOPSIS
    Adds a device to an Azure AD security group.
    
    .DESCRIPTION
    Performs the group membership addition operation with comprehensive error handling
    and validation.
    
    .PARAMETER GroupId
    The Object ID of the Azure AD security group.
    
    .PARAMETER DeviceObjectId
    The Azure AD Object ID of the device to add.
    
    .PARAMETER DeviceDisplayInfo
    Display information about the device for logging purposes.
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$GroupId,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceObjectId,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceDisplayInfo
    )
    
    try {
        Write-Verbose "Adding device $DeviceDisplayInfo to group $GroupId"
        
        # Attempt to add the device to the specified security group
        New-MgGroupMember -GroupId $GroupId -DirectoryObjectId $DeviceObjectId -ErrorAction Stop
        
        Write-Information "Successfully added device '$DeviceDisplayInfo' to group '$GroupId'" -InformationAction Continue
        return $true
    }
    catch {
        # Provide detailed error information for troubleshooting
        $errorMessage = "Failed to add device '$DeviceDisplayInfo' to group '$GroupId': $($_.Exception.Message)"
        Write-Error $errorMessage
        return $false
    }
}

# Main script execution begins here
try {
    # Validate and import required modules
    if (-not (Test-RequiredModules)) {
        exit 1
    }
    
    Import-RequiredModules
    
    # Determine device query method and retrieve devices
    $devices = $null
    
    # Query devices based on parameter set
    switch ($PSCmdlet.ParameterSetName) {
        'ByUser' {
            # Query devices by device owner UPN
            $devices = Get-ManagedDevicesByUser -UserPrincipalName $UserPrincipalName
        }
        'ByDeviceName' {
            # Query devices by device display name
            $devices = Get-ManagedDevicesByName -DeviceName $DeviceName
        }
        'ByDeviceId' {
            # Query specific device by ID
            try {
                $specificDevice = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $DeviceId | 
                    Select-Object ManagedDeviceName, Id, DeviceName, Manufacturer, AzureAdDeviceId, UserPrincipalName, UserId
                if ($specificDevice) {
                    $devices = @($specificDevice)
                }
            }
            catch {
                Write-Error "Failed to retrieve device with ID '$DeviceId': $($_.Exception.Message)"
                exit 1
            }
        }
        'Interactive' {
            # Interactive mode - prompt for device selection method
            Write-Information "`n=== Device Selection Method ===" -InformationAction Continue
            Write-Information "1. Search by device owner (User Principal Name)" -InformationAction Continue
            Write-Information "2. Search by device name" -InformationAction Continue
            Write-Information "3. Enter specific device ID" -InformationAction Continue
            
            do {
                $choice = Read-Host -Prompt "Select search method (1-3)"
            } while ($choice -notin @('1', '2', '3'))
            
            switch ($choice) {
                '1' {
                    do {
                        $UserPrincipalName = Read-Host -Prompt "Enter the UPN of the device owner"
                    } while ([string]::IsNullOrWhiteSpace($UserPrincipalName))
                    $devices = Get-ManagedDevicesByUser -UserPrincipalName $UserPrincipalName
                }
                '2' {
                    do {
                        $DeviceName = Read-Host -Prompt "Enter the device name (or partial name)"
                    } while ([string]::IsNullOrWhiteSpace($DeviceName))
                    $devices = Get-ManagedDevicesByName -DeviceName $DeviceName
                }
                '3' {
                    do {
                        $DeviceId = Read-Host -Prompt "Enter the Intune Device ID (GUID) of the device"
                    } while ([string]::IsNullOrWhiteSpace($DeviceId))
                    
                    # Query specific device by ID
                    try {
                        $specificDevice = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $DeviceId | 
                            Select-Object ManagedDeviceName, Id, DeviceName, Manufacturer, AzureAdDeviceId, UserPrincipalName, UserId
                        if ($specificDevice) {
                            $devices = @($specificDevice)
                        }
                    }
                    catch {
                        Write-Error "Failed to retrieve device with ID '$DeviceId': $($_.Exception.Message)"
                        exit 1
                    }
                }
            }
        }
    }
    
    # Check if any devices were found
    if ($null -eq $devices -or $devices.Count -eq 0) {
        Write-Error "No devices found matching the specified criteria"
        exit 1
    }
    
    # Display available devices in a formatted table
    Write-Information "`nAvailable devices:" -InformationAction Continue
    $devices | Format-Table -AutoSize
    
    # Get Device ID (prompt if not provided)
    if (-not $DeviceId) {
        do {
            $DeviceId = Read-Host -Prompt "Enter the Intune Device ID (Id column) of the device to be added to the group"
        } while ([string]::IsNullOrWhiteSpace($DeviceId))
    }
    
    # Validate that the provided Device ID exists in the retrieved devices
    $selectedDevice = $devices | Where-Object { $_.Id -eq $DeviceId }
    if ($null -eq $selectedDevice) {
        Write-Error "Device ID '$DeviceId' not found in the list of devices"
        exit 1
    }
    
    # Get Azure AD Object ID for the selected device
    $azureAdObjectId = Get-AzureADObjectIdFromDevice -AzureAdDeviceId $selectedDevice.AzureAdDeviceId
    if ($null -eq $azureAdObjectId) {
        Write-Error "Unable to retrieve Azure AD Object ID for device: $($selectedDevice.ManagedDeviceName)"
        exit 1
    }
    
    # Get Group Name (prompt if not provided)
    if (-not $GroupName) {
        do {
            $GroupName = Read-Host -Prompt "Enter the Azure AD Group Name to add the device to"
        } while ([string]::IsNullOrWhiteSpace($GroupName))
    }
    
    # Retrieve eligible security groups
    $eligibleGroups = Get-EligibleSecurityGroups -GroupName $GroupName
    if ($null -eq $eligibleGroups) {
        Write-Error "No eligible security groups found with name: $GroupName"
        exit 1
    }
    
    # Display available groups in a formatted table
    Write-Information "`nEligible security groups:" -InformationAction Continue
    $eligibleGroups | Select-Object DisplayName, Id, Description, GroupTypes, SecurityEnabled | Format-Table -AutoSize
    
    # Get Group ID selection (prompt for selection if multiple groups found)
    if ($eligibleGroups.Count -eq 1) {
        $selectedGroupId = $eligibleGroups[0].Id
        Write-Information "Auto-selected the only eligible group: $($eligibleGroups[0].DisplayName)" -InformationAction Continue
    } else {
        do {
            $selectedGroupId = Read-Host -Prompt "Enter the Group ID (Id column) of the group to add the device to"
        } while ([string]::IsNullOrWhiteSpace($selectedGroupId))
        
        # Validate that the selected Group ID exists in the eligible groups
        if ($selectedGroupId -notin $eligibleGroups.Id) {
            Write-Error "Group ID '$selectedGroupId' not found in the list of eligible groups"
            exit 1
        }
    }
    
    # Perform the group membership addition
    $deviceDisplayInfo = "$($selectedDevice.ManagedDeviceName) ($($selectedDevice.AzureAdDeviceId))"
    $success = Add-DeviceToSecurityGroup -GroupId $selectedGroupId -DeviceObjectId $azureAdObjectId -DeviceDisplayInfo $deviceDisplayInfo
    
    if ($success) {
        Write-Information "Operation completed successfully" -InformationAction Continue
        exit 0
    } else {
        Write-Error "Operation failed"
        exit 1
    }
}
catch {
    # Handle any unhandled exceptions at the script level
    Write-Error "Script execution failed: $($_.Exception.Message)"
    Write-Verbose "Full exception details: $($_.Exception | Format-List -Force | Out-String)"
    exit 1
}
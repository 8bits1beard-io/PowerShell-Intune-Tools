# PowerShell-Intune-Tools

A collection of PowerShell scripts for managing and automating Microsoft Intune and Azure AD device operations.

## Table of Contents

### Scripts

| Script Name | Description | Parameters | Usage |
|-------------|-------------|------------|-------|
| [Get-ObjectID.ps1](#get-objectidps1) | Retrieves Azure AD device Object IDs from Microsoft Graph based on device display names | `-DeviceName`, `-InputFilePath`, `-OutputFilePath` | Single device lookup or bulk operations from file |
| [Add-ManagedDeviceToAADGroup.ps1](#add-manageddevicetoaadgroupps1) | Adds Microsoft Intune managed devices to Azure Active Directory security groups | `-UserPrincipalName`, `-DeviceName`, `-DeviceId`, `-GroupName` | Interactive workflow to add devices to security groups |
| [Set-EntraGroupDistribution.ps1](#set-entragroupdistributionps1) | Distributes device members from a source Entra group to target groups based on specified percentages | `-LogPath`, `-SkipModuleInstall` | Interactive percentage-based group distribution |

---

## Script Details

### Get-ObjectID.ps1

**Purpose**: Retrieves Azure AD device Object IDs from Microsoft Graph based on device display names.

**Features**:
- Single device lookup with console output
- Bulk operations from text file with CSV export
- Interactive mode with user prompts
- Automatic Microsoft.Graph module installation
- Comprehensive error handling and status reporting

**Parameters**:
- `DeviceName` (String): Single device display name for lookup
- `InputFilePath` (String): Path to text file containing device names (one per line)
- `OutputFilePath` (String): Path for output CSV file (defaults to "C:\Temp\DeviceObjectIDs.csv")

**Examples**:
```powershell
# Single device lookup
.\Get-ObjectID.ps1 -DeviceName "DESKTOP-ABC123"

# Bulk operation from file
.\Get-ObjectID.ps1 -InputFilePath "C:\temp\hostnames.txt"

# Bulk operation with custom output path
.\Get-ObjectID.ps1 -InputFilePath "C:\temp\hostnames.txt" -OutputFilePath "C:\temp\results.csv"

# Interactive mode (no parameters)
.\Get-ObjectID.ps1
```

**Prerequisites**:
- Microsoft.Graph PowerShell module (auto-installed if missing)
- Azure AD permissions: `Device.Read.All`

---

### Add-ManagedDeviceToAADGroup.ps1

**Purpose**: Adds Microsoft Intune managed devices to Azure Active Directory security groups through an interactive workflow.

**Features**:
- Multiple device search methods (by owner UPN, device name, or device ID)
- Interactive device selection with formatted tables
- Security group filtering (security-enabled, static membership only)
- Comprehensive error handling and validation
- Auto-selection when only one option is available
- Detailed status reporting and logging

**Parameters**:
- `UserPrincipalName` (String): UPN of device owner to filter managed devices
- `DeviceName` (String): Display name of the managed device to search for
- `DeviceId` (String): Intune Device ID of the specific device to add
- `GroupName` (String): Display name of the Azure AD security group

**Examples**:
```powershell
# Interactive mode with full prompts
.\Add-ManagedDeviceToAADGroup.ps1

# Search by device owner
.\Add-ManagedDeviceToAADGroup.ps1 -UserPrincipalName "user@contoso.com"

# Search by device name
.\Add-ManagedDeviceToAADGroup.ps1 -DeviceName "DESKTOP-ABC123"

# Direct device and group specification
.\Add-ManagedDeviceToAADGroup.ps1 -DeviceId "12345678-1234-1234-1234-123456789012" -GroupName "Security-Devices"
```

**Prerequisites**:
- Microsoft.Graph.Groups PowerShell module
- Microsoft.Graph.DeviceManagement PowerShell module
- Microsoft.Graph.Identity.DirectoryManagement PowerShell module
- Azure AD permissions: `DeviceManagementManagedDevices.Read.All`, `Device.Read.All`, `Group.ReadWrite.All`

---

### Set-EntraGroupDistribution.ps1

**Purpose**: Interactively distributes device members from a source Entra group to target groups based on specified percentages.

**Features**:
- Interactive configuration interface for source and target groups
- Percentage-based distribution with validation (total must equal 100%)
- GUID format validation for group IDs
- Configuration summary with user confirmation
- Automatic Microsoft Graph connection with required scopes
- Integration with AzureGroupStuff module for distribution logic
- Comprehensive logging with JSON-formatted entries

**Parameters**:
- `LogPath` (String): Directory path for diagnostic logs (defaults to "C:\Windows\Logs")
- `SkipModuleInstall` (Switch): Skip automatic installation of required modules

**Examples**:
```powershell
# Interactive mode with module installation
.\Set-EntraGroupDistribution.ps1

# Skip module installation
.\Set-EntraGroupDistribution.ps1 -SkipModuleInstall

# Custom log path
.\Set-EntraGroupDistribution.ps1 -LogPath "D:\Logs"
```

**Prerequisites**:
- AzureGroupStuff PowerShell module
- Microsoft.Graph.Authentication PowerShell module
- Microsoft.Graph.Groups PowerShell module
- Azure AD permissions: `Device.Read.All`, `User.Read.All`, `Group.ReadWrite.All`, `DeviceManagementManagedDevices.Read.All`

---

## Installation

1. Clone this repository:
```powershell
git clone https://github.com/yourusername/PowerShell-Intune-Tools.git
```

2. Navigate to the repository directory:
```powershell
cd PowerShell-Intune-Tools
```

3. Run the desired script with appropriate parameters or in interactive mode.

## Requirements

- PowerShell 5.1 or later
- Microsoft.Graph PowerShell modules (specific modules listed per script)
- Appropriate Azure AD permissions for the operations being performed

## Contributing

When contributing to this repository, please ensure all scripts follow the PowerShell best practices and style guidelines outlined in the repository standards.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

**8bits1beard**
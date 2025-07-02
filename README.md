# PowerShell-Intune-Tools

A collection of PowerShell scripts for managing and automating Microsoft Intune and Azure AD device operations.

## Table of Contents

### Scripts

| Script Name | Description | Parameters | Usage |
|-------------|-------------|------------|-------|
| [Get-ObjectID.ps1](#get-objectidps1) | Retrieves Azure AD device Object IDs from Microsoft Graph based on device display names | `-DeviceName`, `-InputFilePath`, `-OutputFilePath` | Single device lookup or bulk operations from file |

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
- Microsoft.Graph PowerShell module
- Appropriate Azure AD permissions for the operations being performed

## Contributing

When contributing to this repository, please ensure all scripts follow the PowerShell best practices and style guidelines outlined in the repository standards.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

**8bits1beard**
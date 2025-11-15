# Chocolatey Application Installer

A powerful and user-friendly PowerShell script for automated application installation using Chocolatey package manager on Windows.

## Features

- ✅ **Automatic Chocolatey Installation** - Installs Chocolatey if not present
- ✅ **Batch Application Installation** - Install multiple applications at once
- ✅ **JSON Configuration Support** - Easy-to-manage application lists
- ✅ **Remote Execution** - Run via `irm | iex` for quick deployment
- ✅ **Version Control** - Specify exact versions for applications
- ✅ **Custom Parameters** - Pass installation parameters to packages
- ✅ **Error Handling** - Robust error detection and reporting
- ✅ **Colorful Output** - Visual feedback with color-coded messages
- ✅ **Administrator Check** - Ensures proper permissions
- ✅ **Installation Summary** - Detailed success/failure statistics

## Prerequisites

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or higher
- Administrator privileges
- Internet connection

## Quick Start

### Method 1: Local Execution

1. Download the script:
   ```powershell
   git clone https://github.com/yourusername/chocolatey-script.git
   cd chocolatey-script
   ```

2. Run the basic installer:
   ```powershell
   .\install-apps.ps1
   ```

### Method 2: Remote Execution (irm | iex)

Execute directly from a URL without downloading:

```powershell
irm https://raw.githubusercontent.com/yourusername/chocolatey-script/main/install-apps.ps1 | iex
```

⚠️ **Security Warning**: Only execute scripts from trusted sources when using remote execution!

### Method 3: Using Preset Configurations

```powershell
# Basic applications (browsers, utilities, etc.)
.\install-apps.ps1 -ConfigFile "basic-apps-config.json"

# Developer tools
.\install-apps.ps1 -ConfigFile "dev-tools-config.json"

# Gaming applications
.\install-apps.ps1 -ConfigFile "gaming-config.json"

# Communication tools
.\install-apps.ps1 -ConfigFile "community-config.json"
```

## Usage Examples

### Install Default Applications

```powershell
# Installs: Chrome, Firefox, VSCode, 7-Zip, Git, Notepad++
.\install-apps.ps1
```

### Install Custom Application List

```powershell
# Edit the script and customize the $Applications array
Install-Applications -Applications @(
    @{ Name = 'googlechrome'; Version = $null; Params = @() },
    @{ Name = 'python'; Version = '3.11.0'; Params = @('--params', '/InstallDir:C:\Python311') },
    @{ Name = 'nodejs'; Version = $null; Params = @() }
)
```

### Using Preset Configurations

```powershell
# Install basic applications (browsers, 7-Zip, VLC, etc.)
.\install-apps.ps1 -ConfigFile "basic-apps-config.json"

# Install developer tools (VSCode, Git, Docker, Python, etc.)
.\install-apps.ps1 -ConfigFile "dev-tools-config.json"

# Install communication tools (Teams, Zoom, Slack, etc.)
.\install-apps.ps1 -ConfigFile "community-config.json"

# Install gaming applications (Steam, Discord, OBS, etc.)
.\install-apps.ps1 -ConfigFile "gaming-config.json"
```

### Using Advanced Management Script

```powershell
# Install applications from default config
.\manage-apps.ps1 -Action Install

# Install from specific config
.\manage-apps.ps1 -Action Install -ConfigFile "dev-tools-config.json"

# Update all installed applications
.\manage-apps.ps1 -Action Update

# Uninstall applications
.\manage-apps.ps1 -Action Uninstall

# List installed applications status
.\manage-apps.ps1 -Action List

# Upgrade all Chocolatey packages
.\manage-apps.ps1 -Action Upgrade
```

## Available Preset Configurations

### 🔧 basic-apps-config.json
Common Windows applications:
- Browsers: Chrome, Edge, Firefox, Brave
- PDF: Foxit Reader
- Utilities: 7-Zip, WinRAR, VLC, Revo Uninstaller, PowerToys
- Vietnamese: UniKey
- System: .NET 3.5, Patch My PC, Winaero Tweaker

### 💬 community-config.json
Communication tools:
- Microsoft Teams, Zoom, Slack
- Telegram, Zalo PC

### 💻 dev-tools-config.json
Developer essentials:
- IDEs: VSCode
- VCS: Git, GitHub Desktop
- Runtime: Node.js LTS, Python, Docker Desktop
- Tools: cURL, wget, PowerShell Core, Windows Terminal, WSL2
- Extensions: VSCode Python

### 🎮 gaming-config.json
Gaming applications:
- Platforms: Steam, Epic Games Launcher
- Communication: Discord
- Streaming: OBS Studio
- Utilities: GeForce Experience, MSI Afterburner, HWiNFO, CrystalDiskInfo, CPU-Z
- Media: VLC

## Configuration File Format

The JSON configuration file uses the following structure:

```json
{
  "applications": [
    {
      "name": "package-name",        // Required: Chocolatey package name
      "version": "1.0.0",            // Optional: Specific version (null for latest)
      "params": ["--param", "value"] // Optional: Additional parameters
    }
  ]
}
```

### Common Package Examples

```json
{
  "applications": [
    {
      "name": "googlechrome",
      "version": null,
      "params": []
    },
    {
      "name": "git",
      "version": null,
      "params": ["--params", "/GitAndUnixToolsOnPath"]
    },
    {
      "name": "python",
      "version": "3.11.0",
      "params": ["--params", "/InstallDir:C:\\Python311"]
    },
    {
      "name": "nodejs-lts",
      "version": null,
      "params": []
    },
    {
      "name": "docker-desktop",
      "version": null,
      "params": []
    }
  ]
}
```

## Popular Chocolatey Packages

### Browsers
- `googlechrome` - Google Chrome
- `firefox` - Mozilla Firefox
- `brave` - Brave Browser
- `microsoft-edge` - Microsoft Edge

### Development Tools
- `vscode` - Visual Studio Code
- `visualstudio2022community` - Visual Studio 2022
- `git` - Git version control
- `github-desktop` - GitHub Desktop
- `postman` - Postman API platform
- `docker-desktop` - Docker Desktop

### Programming Languages
- `python` - Python
- `nodejs-lts` - Node.js LTS
- `golang` - Go
- `openjdk` - OpenJDK Java
- `dotnet-sdk` - .NET SDK

### Utilities
- `7zip` - 7-Zip archiver
- `notepadplusplus` - Notepad++
- `vlc` - VLC Media Player
- `adobereader` - Adobe Reader
- `teamviewer` - TeamViewer
- `windirstat` - WinDirStat

### Communication
- `slack` - Slack
- `discord` - Discord
- `zoom` - Zoom
- `microsoft-teams` - Microsoft Teams

## Troubleshooting

### Script execution is disabled

If you get an error about script execution policy:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Not running as Administrator

Right-click PowerShell and select "Run as Administrator"

### Chocolatey installation fails

1. Ensure you have internet connection
2. Check if proxy settings are required
3. Try manual installation from [chocolatey.org](https://chocolatey.org/install)

### Package installation fails

1. Check package name at [chocolatey.org/packages](https://community.chocolatey.org/packages)
2. Verify version exists
3. Check system requirements for the package
4. Review error messages in output

### Refresh environment variables

After installation, you may need to refresh your environment:

```powershell
refreshenv
# or restart PowerShell
```

## Security Best Practices

1. **Review Scripts**: Always review scripts before executing, especially from remote sources
2. **Trusted Sources**: Only use `irm | iex` with URLs you trust
3. **HTTPS Only**: Ensure remote scripts are served over HTTPS
4. **Version Pinning**: Specify exact versions for critical applications
5. **Backup**: Create system restore point before bulk installations

## Advanced Features

### Custom Installation Path

```powershell
@{
    Name = 'python';
    Version = '3.11.0';
    Params = @('--params', '/InstallDir:C:\CustomPath\Python311')
}
```

### Silent Installation Parameters

```powershell
@{
    Name = 'vscode';
    Version = $null;
    Params = @('--params', '/NoDesktopIcon /NoQuicklaunchIcon')
}
```

### Install from Private Repository

```powershell
choco source add -n=private-repo -s="https://your-private-repo.com/nuget"
```

## File Structure

```
Chocolatey_Script/
├── install-apps.ps1              # Smart installer (supports both modes)
├── manage-apps.ps1               # Advanced management script
├── basic-apps-config.json        # Basic applications preset (15 apps)
├── community-config.json         # Communication tools preset (5 apps)
├── dev-tools-config.json         # Developer tools preset (15 apps)
├── gaming-config.json            # Gaming applications preset (10 apps)
├── .gitignore                    # Git ignore rules
├── LICENSE                       # MIT License
└── README.md                     # This file
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Resources

- [Chocolatey Official Website](https://chocolatey.org/)
- [Chocolatey Package Gallery](https://community.chocolatey.org/packages)
- [Chocolatey Documentation](https://docs.chocolatey.org/)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)

## Changelog

### Version 1.0.0
- Initial release
- Basic installation functionality
- JSON configuration support
- Advanced management features
- Comprehensive documentation

---

**Made with ❤️ for Windows automation**

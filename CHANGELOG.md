# Changelog

## [Latest] - 2025-01-18

### Added
- **Return to Main Menu feature**: After completing any action (Install/Update/Uninstall/List/Upgrade), users can now choose to:
  - Return to Main Menu to perform another action
  - Exit the program
- **Interactive loop mode**: Script now runs continuously until user chooses to exit
- **New `Show-ContinuePrompt()` function**: Displays menu after each operation

### Optimizations Applied
- **Global cache system** for Chocolatey packages (5-minute cache)
  - `$script:ChocoPackagesCache` - caches package list
  - `$script:CacheTimestamp` - tracks cache time
  - Significantly improves performance when checking multiple packages

- **Extracted nested functions** to module level:
  - `Get-FriendlyName()` - converts package names to display names
  - `Get-SearchNames()` - generates search patterns for registry detection
  - Eliminates function redefinition overhead

- **New helper functions**:
  - `Get-ChocoPackagesCache()` - centralized cache management
  - `Get-ConfigApplications()` - consolidated config loading logic
  - `Invoke-MainWorkflow()` - main execution workflow

- **Code deduplication**:
  - Removed ~120 lines of duplicate config loading code
  - Consolidated preset config map to single global variable
  - Reduced config file references from 10+ to 4-5

### Performance Improvements
- **Before**: Each package check = 2-5 seconds (runs `choco list` every time)
- **After**: Multiple checks = 1 `choco list` call, cached for 5 minutes
- **Improved** registry detection with ghost entry filtering
- **Faster** installation status checking

### Changed
- Main execution now wrapped in `Invoke-MainWorkflow()` function
- Script supports both single-run (with parameters) and interactive loop modes
- When using command-line parameters, script shows continue prompt if `-KeepWindowOpen` is specified

### Fixed
- Removed nested function definitions causing performance overhead
- Eliminated duplicate code blocks in preset/config handling

## Usage Examples

### Interactive Mode (Default)
```powershell
.\install-apps.ps1
```
User will see menu → perform action → choose to continue or exit → repeat

### Command-Line Mode with Continue Option
```powershell
.\install-apps.ps1 -Preset basic -KeepWindowOpen
```
Install basic preset → show "Return to Menu or Exit" prompt

### Command-Line Mode (Run Once)
```powershell
.\install-apps.ps1 -Preset basic
```
Install basic preset → exit immediately (no prompt)

# Changelog

## [v2.0.0] - 2025-02-01 - Hybrid Engine & Smart GUI

### Added
- **Hybrid Package Manager Engine**: Tích hợp toàn diện với **Winget** bên cạnh Chocolatey. Script giờ đây có thể tự động chọn nguồn tốt nhất (phiên bản mới nhất) hoặc tự động chuyển sang nguồn khác nếu một nguồn thất bại.
- **Smart GUI cho Custom Selection**:
  - Giao diện **Checkbox Form** mới, trực quan và thân thiện, được đặt làm mặc định khi chọn ứng dụng tùy chỉnh.
  - Tự động chuyển sang `Out-GridView` hoặc menu dạng văn bản trên các môi trường không hỗ trợ Windows Forms (ví dụ: Windows Server Core, SSH).
- **Tự động cài đặt Winget**: Nếu không tìm thấy Winget trên hệ điều hành được hỗ trợ, script sẽ đề nghị tải và cài đặt tự động.
- **Chính sách Nguồn Gói (Package Source Policy)**:
  - Thêm file `package-policy.json` cho phép người dùng "ghim" (pin) phiên bản hoặc ưu tiên sử dụng Chocolatey/Winget cho các gói cụ thể.
  - Thêm mục "Manage Package Policies" trong menu chính để quản lý file này.
- **Ánh xạ Winget ID**: Sử dụng file `winget-map.json` để ánh xạ tên gói Chocolatey sang Winget ID tương ứng, giúp hoạt động liền mạch.
- **Tham số `-UseWinget`**: Cho phép bật/tắt tích hợp Winget một cách tường minh.

### Changed
- **Nâng cấp toàn diện**: Chức năng `Upgrade` giờ là `Upgrade (Hybrid)`, thực hiện cả `choco upgrade all` và `winget upgrade --all` để cập nhật toàn bộ hệ thống.
- **Cải tiến các chức năng cốt lõi**: Các chế độ `Install`, `Update`, `Uninstall` giờ đây tận dụng engine hybrid, giúp thực thi mạnh mẽ và đáng tin cậy hơn.
- **Cải tiến chế độ `List`**: Nay hiển thị rõ nguồn cài đặt của ứng dụng: `[Choco]`, `[Winget]`, hoặc `[Manual]` (phát hiện qua registry).
- **Hành vi mặc định**: Tích hợp Winget được tự động kích hoạt nếu lệnh `winget.exe` được tìm thấy.

### Fixed
- Tăng tỷ lệ cài đặt thành công nhờ cơ chế tự động dự phòng (fallback) giữa Chocolatey và Winget.

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

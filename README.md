# VSBTek Chocolatey Installer

Công cụ PowerShell tự động cài đặt và quản lý ứng dụng Windows qua Chocolatey với hỗ trợ remote execution và preset configurations.

## Yêu cầu hệ thống

- **Operating System**: Windows 10/11 hoặc Windows Server 2016+
- **PowerShell**: Version 5.1 trở lên (đã có sẵn trong Windows 10/11)
- **Execution Policy**: Cần quyền chạy scripts (script sẽ tự động xử lý)
- **Administrator Rights**: Bắt buộc (script sẽ tự động yêu cầu elevation)
- **Internet Connection**: Cần thiết để tải packages từ Chocolatey repository
- **.NET Framework**: .NET 4.8+ (thường đã có sẵn trên Windows 10/11)

**Kiểm tra PowerShell version:**
```powershell
$PSVersionTable.PSVersion
```

## Cài đặt nhanh

### Từ Web (Khuyên dùng)

**Cách 1: One-liner siêu ngắn (Nhanh nhất)** ⚡
```powershell
# Từ GitHub (Hoạt động ngay)
irm https://raw.githubusercontent.com/HenryBui21/VSBTek-Chocolatey-Installer/main/quick-install.ps1 | iex

# Hoặc từ scripts.vsbtek.com (nếu đã cấu hình)
irm https://scripts.vsbtek.com/quick-install.ps1 | iex
```
✅ **Khuyên dùng** - Lệnh ngắn gọn nhất, tự động tải và chạy interactive mode

**Cách 2: Tải về và chạy (Linh hoạt nhất)**
```powershell
# Tải script về và chạy interactive mode
irm https://scripts.vsbtek.com/install-apps.ps1 -OutFile install-apps.ps1
.\install-apps.ps1

# Hoặc chạy trực tiếp với preset
irm https://scripts.vsbtek.com/install-apps.ps1 -OutFile install-apps.ps1
.\install-apps.ps1 -Preset basic -Mode remote
```

**Cách 3: One-liner với temp folder**
```powershell
irm https://scripts.vsbtek.com/install-apps.ps1 -OutFile "$env:TEMP\install-apps.ps1"; & "$env:TEMP\install-apps.ps1"
```

### Từ Local

```powershell
# Interactive mode với menu
.\install-apps.ps1

# Cài đặt với preset
.\install-apps.ps1 -Preset basic

# Cài đặt với config file tùy chỉnh
.\install-apps.ps1 -ConfigFile "my-apps.json"

# Quản lý ứng dụng
.\install-apps.ps1 -Action Update -Preset dev
.\install-apps.ps1 -Action List -Preset gaming
.\install-apps.ps1 -Action Upgrade
```

⚠️ **Lưu ý**: Script tự động yêu cầu quyền Administrator khi cần.

## Preset có sẵn

### 🔧 Basic Apps (18 ứng dụng)

Trình duyệt, công cụ nén, PDF reader, tiện ích Windows:

- **Browsers**: Chrome, Edge, Firefox, Brave
- **Utilities**: 7-Zip, WinRAR, VLC, Notepad++, PowerToys, Revo Uninstaller
- **Tools**: Foxit Reader, TreeSize Free, UltraViewer, Patch My PC, Winaero Tweaker
- **Language**: UniKey
- **Runtime**: .NET 3.5, .NET 8.0 Desktop Runtime

### 💻 Dev Tools (15 ứng dụng)

IDE, runtime, version control, Docker:

- **IDEs**: VSCode + Python Extension
- **VCS**: Git, GitHub Desktop
- **Runtime**: Node.js LTS, Python, .NET SDK
- **Tools**: Docker Desktop, cURL, wget, PowerShell 7, Windows Terminal, WSL2

### 💬 Community (5 ứng dụng)

Ứng dụng giao tiếp:

- Microsoft Teams, Zoom, Slack, Telegram, Zalo PC

### 🎮 Gaming (10 ứng dụng)

Gaming platform và tiện ích:

- **Platforms**: Steam, Epic Games
- **Tools**: Discord, OBS Studio, GeForce Experience, MSI Afterburner
- **Monitoring**: HWiNFO, CrystalDiskInfo, CPU-Z
- **Media**: VLC

### 🎯 Custom Selection - TỰ CHỌN ỨNG DỤNG

**MỚI!** Không muốn cài cả preset? Chọn từng ứng dụng riêng lẻ!

**2 chế độ lựa chọn:**

1. **GUI Mode (Out-GridView)** - Khuyên dùng
   - Cửa sổ đồ họa với checkboxes
   - Search/filter apps theo tên
   - Ctrl+Click để chọn nhiều apps
   - Hoạt động trên Windows 10/11

2. **Text Mode** - Fallback tự động
   - Menu dạng text nếu GUI không available
   - Chọn bằng số: `1,3,5` hoặc range `1-10`
   - Type `all` để chọn tất cả

**Cách sử dụng:**
```powershell
# Interactive mode - chọn option "5. Custom Selection"
.\install-apps.ps1

# Hoặc command-line trực tiếp
.\install-apps.ps1 -Preset custom
```

**Ví dụ Out-GridView:**
![image](https://user-images.githubusercontent.com/sample/outgridview.png)
```
Hiển thị tất cả ~44 apps từ 4 categories:
✓ Chrome [Basic Apps]
✓ VSCode [Dev Tools]
✓ Discord [Gaming]
... user chọn và click OK
```

## Các chế độ hoạt động

### 1. Install Mode (Mặc định)

```powershell
# Interactive - chọn preset từ menu
.\install-apps.ps1

# Cài preset cụ thể
.\install-apps.ps1 -Preset basic
.\install-apps.ps1 -Preset dev
.\install-apps.ps1 -Preset community
.\install-apps.ps1 -Preset gaming

# Cài từ config file tùy chỉnh
.\install-apps.ps1 -ConfigFile "my-apps.json"

# Cài từ remote (GitHub)
.\install-apps.ps1 -Preset basic -Mode remote
```

### 2. Update Mode

```powershell
# Cập nhật tất cả apps trong preset
.\install-apps.ps1 -Action Update -Preset dev

# Cập nhật từ config file
.\install-apps.ps1 -Action Update -ConfigFile "dev-tools-config.json"
```

### 3. Uninstall Mode

```powershell
# Gỡ cài đặt apps trong preset
.\install-apps.ps1 -Action Uninstall -Preset gaming

# Gỡ cài đặt với force
.\install-apps.ps1 -Action Uninstall -Preset community -Force
```

### 4. List Mode

```powershell
# Liệt kê trạng thái cài đặt
.\install-apps.ps1 -Action List -Preset basic
.\install-apps.ps1 -Action List -ConfigFile "gaming-config.json"
```

### 5. Upgrade Mode

```powershell
# Nâng cấp TẤT CẢ Chocolatey packages
.\install-apps.ps1 -Action Upgrade
```

## Tùy chỉnh Config

Format file JSON:

```json
{
  "applications": [
    {
      "name": "googlechrome",
      "version": null,
      "params": []
    },
    {
      "name": "python",
      "version": "3.11.0",
      "params": ["--params", "/InstallDir:C:\\Python311"]
    }
  ]
}
```

## Tính năng

✅ **Tự động cài Chocolatey** nếu chưa có
✅ **Auto-elevation** - tự xin quyền Administrator
✅ **5 chế độ hoạt động**: Install, Update, Uninstall, List, Upgrade
✅ **Cài hàng loạt** từ JSON config hoặc preset
✅ **Custom Selection** 🆕 - Tự chọn apps riêng lẻ (GUI hoặc text mode)
✅ **Remote execution** qua web với GitHub integration
✅ **Interactive menus** - dễ sử dụng không cần tham số
✅ **Package detection** - kiểm tra Windows Registry
✅ **Environment refresh** sau khi cài
✅ **Version pinning** và custom parameters
✅ **Báo cáo chi tiết** thành công/thất bại
✅ **Xác nhận trước khi thực thi** - an toàn với dữ liệu

## Parameters (Tham số)

| Parameter | Mô tả | Giá trị |
|-----------|-------|---------|
| `-ConfigFile` | Đường dẫn tới file JSON config | Path string |
| `-Action` | Chế độ hoạt động | `Install`, `Update`, `Uninstall`, `List`, `Upgrade` |
| `-Preset` | Preset có sẵn | `basic`, `dev`, `community`, `gaming` |
| `-Mode` | Nguồn config | `local` (mặc định), `remote` (GitHub) |
| `-Force` | Bắt buộc cài đặt/gỡ bỏ | Switch flag |
| `-KeepWindowOpen` | Giữ cửa sổ mở sau khi chạy xong | Switch flag |

## Cấu trúc dự án

```
VSBTek-Chocolatey-Installer/
├── install-apps.ps1              # Script chính (all-in-one)
├── install-apps.ps1.sha256       # SHA256 hash cho security verification
├── quick-install.ps1             # Wrapper script cho one-liner với SHA256 check
├── setup-dev.ps1                 # Quick development environment setup
│
├── basic-apps-config.json        # 18 ứng dụng cơ bản
├── dev-tools-config.json         # 15 dev tools
├── community-config.json         # 5 ứng dụng giao tiếp
├── gaming-config.json            # 10 gaming apps
│
├── docs/                         # Documentation
│   └── AUTOMATION-README.md      # Hướng dẫn automation & hash verification
│
└── scripts/                      # Development scripts (ignored in git)
    ├── README.md                 # Scripts documentation
    ├── utils/                    # Development utilities
    │   ├── update-sha256.ps1     # Manual hash updater
    │   ├── install-git-hooks.ps1 # Git hooks installer
    │   ├── create-manifest.ps1   # Create file manifest
    │   └── verify-manifest.ps1   # Verify all files
    │
    └── tests/                    # Testing scripts
        ├── verify-hash.ps1       # Verify local hash
        ├── verify-github-hash.ps1 # Compare with GitHub
        ├── check-github-sync.ps1  # Check GitHub sync status
        └── simulate-quick-install.ps1 # End-to-end simulation
```

### Dành cho Developers

Nếu bạn muốn contribute hoặc develop locally:

1. **Quick setup**: Chạy `.\setup-dev.ps1` để setup Git hooks và verify structure
   - Script này là **standalone** - không cần external dependencies
   - Tự động cài Git hook để auto-update SHA256 hash khi commit

2. **Documentation**: Xem [docs/AUTOMATION-README.md](docs/AUTOMATION-README.md) để hiểu về automation system

3. **Optional tools**: Development utilities và tests có thể tạo trong `scripts/` (local only, không commit lên Git)

## Xử lý sự cố

**Lỗi execution policy:**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Refresh environment sau khi cài:**

```powershell
refreshenv
# hoặc mở lại PowerShell
```

**Tìm package trên Chocolatey:**

- [https://community.chocolatey.org/packages](https://community.chocolatey.org/packages)

## Xử lý sự cố

### Lỗi thường gặp

#### 1. "Execution Policy không cho phép chạy script"

**Triệu chứng:**

```
File cannot be loaded because running scripts is disabled on this system
```

**Giải pháp:**

```powershell
# Tạm thời cho phép chạy script (khuyên dùng)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Hoặc set cho current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

#### 2. "Chocolatey installation failed"

**Nguyên nhân:** Firewall/antivirus chặn, hoặc lỗi kết nối internet

**Giải pháp:**

```powershell
# Kiểm tra kết nối đến Chocolatey
Test-NetConnection -ComputerName chocolatey.org -Port 443

# Cài Chocolatey thủ công
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

#### 3. "Package installation failed (exit code: 1)"

**Nguyên nhân:**

- Package không tồn tại trên Chocolatey
- Xung đột với phiên bản đã cài
- Thiếu dependencies

**Giải pháp:**

```powershell
# Kiểm tra package có tồn tại không
choco search <package-name>

# Xem thông tin chi tiết
choco info <package-name>

# Thử cài với verbose để xem lỗi chi tiết
choco install <package-name> -y -v

# Force reinstall nếu đã cài
choco install <package-name> -y --force
```

#### 4. "SHA256 checksum mismatch" (Quick Install)

**Nguyên nhân:** File bị thay đổi hoặc corrupted trong quá trình download

**Giải pháp:**

```powershell
# Thử download lại
irm https://raw.githubusercontent.com/HenryBui21/VSBTek-Chocolatey-Installer/main/quick-install.ps1 | iex

# Hoặc dùng local install
git clone https://github.com/HenryBui21/VSBTek-Chocolatey-Installer.git
cd VSBTek-Chocolatey-Installer
.\install-apps.ps1
```

#### 5. "Access denied" hoặc "Administrator privileges required"

**Nguyên nhân:** Script không chạy với quyền admin

**Giải pháp:**

```powershell
# Chạy PowerShell as Administrator
# Cách 1: Right-click PowerShell → Run as Administrator
# Cách 2: Từ Win+X → Windows PowerShell (Admin)

# Script sẽ tự động request elevation, nhưng nếu không:
Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
```

#### 6. "Package đã cài nhưng script không detect được"

**Nguyên nhân:**

- Cài từ nguồn khác (MSI, EXE installer)
- Registry detection chưa cover package đó

**Giải pháp:**

```powershell
# Kiểm tra Chocolatey có biết package không
choco list --local-only | Select-String <package-name>

# Nếu không có trong Chocolatey, reinstall qua Chocolatey
choco install <package-name> -y --force
```

#### 7. "Config file không load được"

**Nguyên nhân:** JSON syntax error hoặc file không tồn tại

**Giải pháp:**

```powershell
# Validate JSON syntax
Get-Content your-config.json | ConvertFrom-Json

# Hoặc dùng online validator: https://jsonlint.com
```

Đảm bảo format đúng:

```json
{
  "applications": [
    {
      "name": "package-name",
      "version": null,
      "params": []
    }
  ]
}
```

### Troubleshooting Commands

```powershell
# Kiểm tra Chocolatey đã cài chưa
choco --version

# List tất cả packages đã cài
choco list --local-only

# Kiểm tra update có sẵn
choco outdated

# Xem logs chi tiết
Get-Content "$env:ChocolateyInstall\logs\chocolatey.log" -Tail 50

# Reset Chocolatey cache
choco list --refresh

# Repair Chocolatey installation
choco upgrade chocolatey -y
```

### Vấn đề khác

Nếu bạn gặp vấn đề không nằm trong list trên:

1. **Kiểm tra logs**: Script có verbose error messages
2. **Chạy với -Verbose**: `.\install-apps.ps1 -Verbose`
3. **Báo lỗi tại**: [GitHub Issues](https://github.com/HenryBui21/VSBTek-Chocolatey-Installer/issues)
4. **Chocolatey Docs**: [https://docs.chocolatey.org/en-us/troubleshooting](https://docs.chocolatey.org/en-us/troubleshooting)

## Tài nguyên

- [Chocolatey Packages](https://community.chocolatey.org/packages)
- [Chocolatey Docs](https://docs.chocolatey.org/)
- [GitHub Repository](https://github.com/HenryBui21/VSBTek-Chocolatey-Installer)

## License

MIT License - xem file [LICENSE](LICENSE)

---

**VSBTek** - Tự động hóa cài đặt Windows

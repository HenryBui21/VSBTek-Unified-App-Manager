# VSBTek Chocolatey Installer

Công cụ PowerShell tự động cài đặt và quản lý ứng dụng Windows qua Chocolatey với hỗ trợ remote execution và preset configurations.

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
├── quick-install.ps1             # Wrapper script cho one-liner
├── basic-apps-config.json        # 18 ứng dụng cơ bản
├── dev-tools-config.json         # 15 dev tools
├── community-config.json         # 5 ứng dụng giao tiếp
└── gaming-config.json            # 10 gaming apps
```

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

## Tài nguyên

- [Chocolatey Packages](https://community.chocolatey.org/packages)
- [Chocolatey Docs](https://docs.chocolatey.org/)
- [GitHub Repository](https://github.com/HenryBui21/VSBTek-Chocolatey-Installer)

## License

MIT License - xem file [LICENSE](LICENSE)

---

**VSBTek** - Tự động hóa cài đặt Windows

# VSBTek Chocolatey Installer

Công cụ PowerShell tự động cài đặt ứng dụng Windows qua Chocolatey với hỗ trợ remote execution và preset configurations.

## Cài đặt nhanh

### Từ Web (Khuyên dùng)

Truy cập [scripts.vsbtek.com](https://scripts.vsbtek.com) và chọn **install-apps.ps1**, hoặc:

```powershell
irm https://scripts.vsbtek.com/install-apps.ps1 | iex
```

### Từ Local

```powershell
# Chạy với menu chọn preset
.\install-apps.ps1

# Hoặc chỉ định config file
.\install-apps.ps1 -ConfigFile "basic-apps-config.json"
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

## Quản lý nâng cao

```powershell
# Cài đặt
.\manage-apps.ps1 -Action Install -ConfigFile "dev-tools-config.json"

# Cập nhật tất cả
.\manage-apps.ps1 -Action Update

# Gỡ cài đặt
.\manage-apps.ps1 -Action Uninstall

# Liệt kê trạng thái
.\manage-apps.ps1 -Action List

# Nâng cấp tất cả packages
.\manage-apps.ps1 -Action Upgrade
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

- Tự động cài Chocolatey nếu chưa có
- Auto-elevation (tự xin quyền Admin)
- Cài hàng loạt từ JSON config
- Remote execution qua web
- Interactive preset menu
- Environment refresh sau khi cài
- Báo cáo chi tiết thành công/thất bại
- Hỗ trợ version pinning và custom params

## Cấu trúc dự án

```
VSBTek-Chocolatey-Installer/
├── install-apps.ps1              # Local installer (có menu)
├── install-from-web.ps1          # Web installer (upload lên web)
├── manage-apps.ps1               # Quản lý: install/update/uninstall
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

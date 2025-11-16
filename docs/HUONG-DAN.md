# Hướng Dẫn Sử Dụng - VSBTek Chocolatey Installer

## Cài Đặt Từ Web (Khuyến Nghị)

### Cách 1: Chế độ Tương Tác (Chọn preset từ menu)

Mở PowerShell với quyền Administrator và chạy lệnh:

```powershell
irm https://scripts.vsbtek.com/install-from-web.ps1 | iex
```

Script sẽ hiển thị menu cho bạn chọn:
1. Basic Apps - Ứng dụng cơ bản
2. Development Tools - Công cụ lập trình
3. Community Apps - Ứng dụng giao tiếp
4. Gaming - Ứng dụng game

### Cách 2: Cài Đặt Trực Tiếp (Không cần chọn menu)

**Cài đặt ứng dụng cơ bản:**
```powershell
irm https://scripts.vsbtek.com/install-from-web.ps1 | iex -Preset basic
```

**Cài đặt công cụ lập trình:**
```powershell
irm https://scripts.vsbtek.com/install-from-web.ps1 | iex -Preset dev
```

**Cài đặt ứng dụng giao tiếp:**
```powershell
irm https://scripts.vsbtek.com/install-from-web.ps1 | iex -Preset community
```

**Cài đặt ứng dụng game:**
```powershell
irm https://scripts.vsbtek.com/install-from-web.ps1 | iex -Preset gaming
```

## Các Preset Có Sẵn

### 🔧 Basic Apps (Ứng dụng cơ bản)
- **Trình duyệt:** Google Chrome, Microsoft Edge, Firefox, Brave
- **Đọc PDF:** Foxit Reader
- **Tiện ích:** 7-Zip, WinRAR, VLC, Notepad++
- **Hệ thống:** .NET 3.5, PowerToys, Winaero Tweaker, Revo Uninstaller
- **Tiếng Việt:** UniKey
- **Cập nhật:** Patch My PC

### 💻 Development Tools (Công cụ lập trình)
- **IDE:** Visual Studio Code
- **Version Control:** Git, GitHub Desktop
- **Ngôn ngữ:** Node.js LTS, Python
- **Container:** Docker Desktop
- **Terminal:** Windows Terminal, PowerShell Core
- **Công cụ:** curl, wget, WSL2
- **Extensions:** VSCode Python

### 💬 Community Apps (Ứng dụng giao tiếp)
- Microsoft Teams
- Zoom
- Slack
- Telegram Desktop
- Zalo PC

### 🎮 Gaming (Ứng dụng game)
- **Nền tảng game:** Steam, Epic Games Launcher
- **Giao tiếp:** Discord
- **Streaming:** OBS Studio
- **Công cụ:** GeForce Experience, MSI Afterburner, HWiNFO
- **Giám sát:** CrystalDiskInfo, CPU-Z
- **Media:** VLC

## Cài Đặt Từ File Local

### Bước 1: Tải về dự án
```powershell
git clone https://github.com/yourusername/VSBTek-Chocolatey-Installer.git
cd VSBTek-Chocolatey-Installer
```

### Bước 2: Chạy script
```powershell
# Chế độ tương tác - chọn preset từ menu
.\install-apps.ps1

# Hoặc chỉ định file config cụ thể
.\install-apps.ps1 -ConfigFile "basic-apps-config.json"
.\install-apps.ps1 -ConfigFile "dev-tools-config.json"
.\install-apps.ps1 -ConfigFile "community-config.json"
.\install-apps.ps1 -ConfigFile "gaming-config.json"
```

## Quản Lý Ứng Dụng Nâng Cao

Script `manage-apps.ps1` cung cấp các chức năng quản lý:

```powershell
# Cài đặt ứng dụng
.\manage-apps.ps1 -Action Install -ConfigFile "basic-apps-config.json"

# Cập nhật tất cả ứng dụng
.\manage-apps.ps1 -Action Update

# Gỡ cài đặt ứng dụng
.\manage-apps.ps1 -Action Uninstall -ConfigFile "basic-apps-config.json"

# Liệt kê trạng thái ứng dụng
.\manage-apps.ps1 -Action List -ConfigFile "basic-apps-config.json"

# Nâng cấp tất cả packages
.\manage-apps.ps1 -Action Upgrade
```

## Xử Lý Sự Cố

### Lỗi: "Script execution is disabled"
Chạy lệnh sau trong PowerShell (Administrator):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Lỗi: "Not running as Administrator"
- Nhấp chuột phải vào PowerShell
- Chọn "Run as Administrator"

### Lỗi cài đặt Chocolatey
1. Kiểm tra kết nối internet
2. Kiểm tra cài đặt proxy nếu có
3. Thử cài đặt thủ công từ [chocolatey.org](https://chocolatey.org/install)

### Làm mới biến môi trường
Sau khi cài đặt, chạy lệnh:
```powershell
refreshenv
# hoặc khởi động lại PowerShell
```

## Tạo Preset Tùy Chỉnh

Tạo file JSON với cấu trúc sau:

```json
{
  "applications": [
    {
      "name": "ten-package",
      "version": null,
      "params": []
    },
    {
      "name": "git",
      "version": null,
      "params": ["--params", "/GitAndUnixToolsOnPath"]
    }
  ]
}
```

Sau đó chạy:
```powershell
.\install-apps.ps1 -ConfigFile "custom-config.json"
```

## Tìm Package Chocolatey

Tìm kiếm packages tại: https://community.chocolatey.org/packages

### Một số package phổ biến:
- `googlechrome` - Google Chrome
- `firefox` - Mozilla Firefox
- `vscode` - Visual Studio Code
- `git` - Git
- `python` - Python
- `nodejs-lts` - Node.js LTS
- `7zip` - 7-Zip
- `vlc` - VLC Media Player
- `notepadplusplus` - Notepad++

## Lưu Ý Bảo Mật

⚠️ **QUAN TRỌNG:**
1. Chỉ chạy script từ nguồn tin cậy
2. Luôn sử dụng HTTPS khi chạy script từ web
3. Xem xét tạo điểm khôi phục hệ thống trước khi cài đặt hàng loạt
4. Kiểm tra nội dung script trước khi chạy

## Hỗ Trợ

Nếu gặp vấn đề:
1. Xem phần Xử Lý Sự Cố ở trên
2. Kiểm tra file README.md để biết thêm chi tiết
3. Đảm bảo chạy PowerShell với quyền Administrator
4. Kiểm tra kết nối internet

## Deploy Lên Website

Xem file `DEPLOYMENT.md` để biết hướng dẫn chi tiết về cách deploy lên `https://scripts.vsbtek.com`

---

**Tạo bởi VSBTek - Tự động hóa cài đặt Windows**

Website: https://scripts.vsbtek.com

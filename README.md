# 🚀 VSBTek Unified App Manager (Modularized)

Công cụ PowerShell **"All-in-One"** giúp bạn tự động hóa việc cài đặt, quản lý ứng dụng Windows cực nhanh chóng và chuyên nghiệp.

✨ **Tính năng nổi bật:**
*   **Hybrid Engine:** Kết hợp sức mạnh của **Winget** (Microsoft) và **Chocolatey**.
*   **Thông minh:** Tự động phát hiện ứng dụng đã cài, tránh cài đè.
*   **Giao diện trực quan:** Menu chọn ứng dụng dạng Checkbox hoặc Text dễ dùng.
*   **Linh hoạt:** Hỗ trợ cài theo Preset (Gói) hoặc chọn lẻ (Custom).
*   **An toàn:** Tự động check hash SHA256 bảo vệ toàn vẹn file.

---

## ⚡ Cài đặt nhanh (Quick Start)

Mở **PowerShell (Run as Administrator)** và chạy lệnh sau để bắt đầu ngay:

### 🌐 1. Online (Khuyên dùng)
Không cần tải file, chạy trực tiếp từ đám mây:

```powershell
irm https://raw.githubusercontent.com/HenryBui21/VSBTek-Unified-App-Manager/main/quick-install.ps1 | iex
```

### 📂 2. Offline (Tải về máy)
Nếu bạn muốn lưu script lại để dùng nhiều lần:

```powershell
git clone https://github.com/HenryBui21/VSBTek-Unified-App-Manager.git
cd VSBTek-Unified-App-Manager
.\install-apps.ps1
```

---

## 📦 Các gói ứng dụng (Presets)

Chúng tôi đã chuẩn bị sẵn các bộ phần mềm chuẩn cho từng nhu cầu:

| Preset | Mô tả | Bao gồm (Ví dụ) |
| :--- | :--- | :--- |
| **🔧 Basic** | Cơ bản cho mọi máy | Chrome, Edge, 7-Zip, Unikey, PDF Reader, VLC... |
| **💻 Dev** | Dành cho Lập trình viên | VS Code, Git, Node.js, Python, Docker, Windows Terminal... |
| **🎮 Gaming** | Dành cho Game thủ | Steam, Epic Games, Discord, MSI Afterburner, OBS Studio... |
| **💬 Community** | Ứng dụng văn phòng | Zoom, Slack, Telegram, Zalo, Microsoft Teams... |
| **🎯 Custom** | **Tự chọn (MỚI)** | Hiển thị bảng chọn để bạn tích chọn từng app theo ý thích! |

---

## 🛠 Hướng dẫn sử dụng chi tiết

### 1. Chế độ tương tác (Interactive Menu)
Đơn giản nhất, chỉ cần chạy script và chọn số từ Menu:
```powershell
.\install-apps.ps1
```

### 2. Cài đặt tự động (Command Line)
Dành cho việc viết script automation hoặc deployment:

```powershell
# Cài gói Basic
.\install-apps.ps1 -Preset basic

# Cài gói Dev và tự động chấp nhận (Force)
.\install-apps.ps1 -Preset dev -Force

# Chỉ liệt kê các ứng dụng đã cài
.\install-apps.ps1 -Action List -Preset gaming
```

### 3. Cập nhật & Gỡ bỏ
```powershell
# Cập nhật tất cả ứng dụng trong gói Dev
.\install-apps.ps1 -Action Update -Preset dev

# Gỡ bỏ toàn bộ gói Gaming
.\install-apps.ps1 -Action Uninstall -Preset gaming
```

---

## 📂 Cấu trúc dự án

Dự án được tổ chức gọn gàng theo mô hình Modular:

```text
VSBTek-Unified-App-Manager/
├── config/                 # Chứa các file cấu hình JSON (*.json)
├── docs/                   # Tài liệu hướng dẫn
├── scripts/
│   └── modules/            # Mã nguồn lõi (Core, UI, Network...)
├── install-apps.ps1        # Script chính (Controller)
├── quick-install.ps1       # Script cài đặt nhanh (Bootstrapper)
└── README.md               # Tài liệu này
```

---

## ❓ Xử lý lỗi thường gặp

**1. Lỗi "Execution Policy"**
> *File cannot be loaded because running scripts is disabled on this system.*
👉 **Sửa:** Chạy lệnh `Set-ExecutionPolicy Bypass -Scope Process -Force` trước.

**2. Lỗi Font chữ / Ký tự lạ**
👉 **Sửa:** Script hỗ trợ tốt nhất trên **Windows Terminal**.

**3. Winget không tìm thấy**
👉 **Sửa:** Script sẽ tự động thử cài Winget hoặc chuyển sang dùng Chocolatey thay thế.

---

## 🤝 Đóng góp (Contribute)

Mọi đóng góp đều được hoan nghênh! Hãy tạo **Issue** hoặc **Pull Request** nếu bạn muốn thêm tính năng mới.

**License:** MIT
**Author:** VSBTek
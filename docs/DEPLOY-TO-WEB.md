# Quick Deployment Guide

## Bước 1: Push Code Lên GitHub

Đảm bảo tất cả files đã được push lên GitHub repository của bạn:

```bash
git add .
git commit -m "Update Chocolatey installer"
git push origin main
```

## Bước 2: Cập Nhật Script URL

Mở file `install-from-web.ps1` và cập nhật 2 biến sau:

```powershell
# Thay thế 'yourusername' và 'VSBTek-Chocolatey-Installer' bằng thông tin repo của bạn
$GitHubRepo = "https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO-NAME/main"

# URL nơi bạn sẽ host script này
$ScriptUrl = "https://scripts.vsbtek.com/install"
```

**Ví dụ:**
```powershell
$GitHubRepo = "https://raw.githubusercontent.com/vsbtek/chocolatey-installer/main"
$ScriptUrl = "https://scripts.vsbtek.com/install"
```

## Bước 3: Upload Script Lên Website

Chỉ cần upload **MỘT** file duy nhất lên `scripts.vsbtek.com`:

```
scripts.vsbtek.com/
└── install       (hoặc install.ps1)
```

**Lưu ý:** Đổi tên `install-from-web.ps1` thành `install` (hoặc giữ nguyên `.ps1` extension)

### Cấu hình Web Server:

**IIS:**
```xml
<staticContent>
    <mimeMap fileExtension=".ps1" mimeType="text/plain" />
</staticContent>
```

**Apache (.htaccess):**
```apache
AddType text/plain .ps1
```

**Nginx:**
```nginx
types {
    text/plain ps1;
}
```

## Bước 4: Test

Sau khi upload, test bằng lệnh:

```powershell
# Test interactive mode
irm https://scripts.vsbtek.com/install | iex

# Test direct preset
irm https://scripts.vsbtek.com/install | iex -Preset basic
```

## Cách Hoạt Động

1. User chạy `irm https://scripts.vsbtek.com/install | iex`
2. Script được download từ website của bạn
3. Script tự động download JSON configs từ GitHub repository
4. Script hiển thị menu hoặc cài đặt preset được chọn
5. Tất cả configs luôn được cập nhật từ GitHub

## Ưu Điểm

✅ **Chỉ cần upload 1 file** lên website
✅ **Configs tự động cập nhật** từ GitHub
✅ **Dễ bảo trì** - chỉ cần push lên GitHub
✅ **Không cần upload lại** khi thay đổi danh sách ứng dụng
✅ **Version control** thông qua Git

## Cập Nhật Configs

Khi muốn thêm/bớt ứng dụng:

1. Sửa file `.json` trong repo
2. Commit và push lên GitHub
3. **XONG** - không cần upload lại gì cả!

## Files Trong Repository

```
VSBTek-Chocolatey-Installer/
├── install-from-web.ps1          # File này upload lên web (đổi tên thành 'install')
├── install-apps.ps1              # Local installer (không cần upload)
├── manage-apps.ps1               # Management tool (không cần upload)
├── basic-apps-config.json        # Được load từ GitHub
├── dev-tools-config.json         # Được load từ GitHub
├── community-config.json         # Được load từ GitHub
├── gaming-config.json            # Được load từ GitHub
└── README.md                     # Documentation
```

## Ví Dụ Sử Dụng Sau Khi Deploy

```powershell
# Interactive - hiện menu
irm https://scripts.vsbtek.com/install | iex

# Cài basic apps
irm https://scripts.vsbtek.com/install | iex -Preset basic

# Cài dev tools
irm https://scripts.vsbtek.com/install | iex -Preset dev

# Cài community apps
irm https://scripts.vsbtek.com/install | iex -Preset community

# Cài gaming apps
irm https://scripts.vsbtek.com/install | iex -Preset gaming
```

## Troubleshooting

**Q: Script báo lỗi không tải được config?**
- Kiểm tra URL GitHub trong script có đúng không
- Đảm bảo repo là public hoặc token được cấu hình đúng

**Q: Script không chạy được?**
- Kiểm tra MIME type trên web server
- Đảm bảo file được serve qua HTTPS

**Q: Muốn đổi tên file?**
- Đổi tên `install-from-web.ps1` → `install` (không extension)
- Hoặc giữ nguyên `.ps1` extension
- Cập nhật `$ScriptUrl` trong script cho khớp

---

**Đơn giản hóa tối đa: 1 file upload, mọi thứ khác từ GitHub!**

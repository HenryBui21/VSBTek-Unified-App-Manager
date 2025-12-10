# Automation Tools - VSBTek Chocolatey Installer

Bộ công cụ tự động hóa để maintain và verify dự án.

## 📋 Danh sách công cụ

### 1. **update-sha256.ps1** - Cập nhật SHA256 hash thủ công

Tính toán và cập nhật SHA256 hash cho `install-apps.ps1`.

**Sử dụng:**
```powershell
.\update-sha256.ps1
```

**Khi nào dùng:**
- Sau khi modify `install-apps.ps1`
- Trước khi commit changes
- Khi muốn verify hash đang đúng

---

### 2. **install-git-hooks.ps1** - Cài đặt Git hooks tự động

Setup pre-commit hook tự động update SHA256 hash.

**Sử dụng:**
```powershell
.\install-git-hooks.ps1
```

**Chỉ cần chạy 1 lần!** Hook sẽ tự động:
- Detect khi `install-apps.ps1` được staged
- Calculate hash mới (LF line endings)
- Update `install-apps.ps1.sha256`
- Stage file `.sha256` vào cùng commit

---

### 3. **verify-hash.ps1** - Verify local hash

Kiểm tra hash của file local có khớp với `.sha256` file không.

**Sử dụng:**
```powershell
.\verify-hash.ps1
```

---

### 4. **verify-github-hash.ps1** - So sánh local vs GitHub

Kiểm tra xem local file có match với file trên GitHub không.

**Sử dụng:**
```powershell
.\verify-github-hash.ps1
```

---

### 5. **check-github-sync.ps1** - Verify GitHub repository sync

Kiểm tra xem file `install-apps.ps1` và `.sha256` trên GitHub có đồng bộ không.

**Sử dụng:**
```powershell
.\check-github-sync.ps1
```

**Khi nào dùng:**
- Sau khi push lên GitHub
- Để verify SHA256 verification sẽ work cho users

---

### 6. **simulate-quick-install.ps1** - Simulate user download

Mô phỏng chính xác những gì xảy ra khi user chạy quick-install.

**Sử dụng:**
```powershell
.\simulate-quick-install.ps1
```

**Test được:**
- Download từ GitHub
- SHA256 verification process
- Xem kết quả PASS hay FAIL

---

## 🔄 Workflow khuyên dùng

### Cài đặt lần đầu:

```powershell
# 1. Install Git hooks (chỉ cần 1 lần)
.\install-git-hooks.ps1
```

### Khi modify install-apps.ps1:

```powershell
# 1. Edit install-apps.ps1 như bình thường
# 2. Stage changes
git add install-apps.ps1

# 3. Commit (hook sẽ tự động update hash!)
git commit -m "feat: Add new feature"

# 4. Push
git push
```

**Bạn không cần manual update hash!** Git hook làm tự động.

### Nếu muốn manual update:

```powershell
# Update hash thủ công
.\update-sha256.ps1

# Verify local
.\verify-hash.ps1

# Stage và commit
git add install-apps.ps1.sha256
git commit -m "chore: Update SHA256 hash"
```

### Verify trước khi push:

```powershell
# Verify local files OK
.\verify-hash.ps1

# (Optional) Sau khi push, verify GitHub sync
.\check-github-sync.ps1

# Test end-to-end như user sẽ thấy
.\simulate-quick-install.ps1
```

---

## 🔐 Tại sao cần SHA256 hash?

**Vấn đề:** GitHub serve raw files với LF line endings, nhưng Windows local có CRLF.

**Giải pháp:** Tính hash với LF endings (match với GitHub).

**Automation giải quyết:**
- ✅ Tự động convert CRLF → LF
- ✅ Tính hash chính xác
- ✅ Không bao giờ quên update
- ✅ SHA256 verification hoạt động 100%

---

## ⚠️ Lưu ý

1. **Git hooks** không được commit vào repo (nằm trong `.git/hooks/`)
2. **Utility scripts** này được ignore trong `.gitignore`
3. Chỉ **install-apps.ps1.sha256** được track trong Git
4. Hook chỉ chạy khi `install-apps.ps1` được staged

---

## 🐛 Troubleshooting

### Hook không chạy?

```powershell
# Re-install hook
.\install-git-hooks.ps1
# Chọn 'y' để overwrite

# Test
git add install-apps.ps1
git commit -m "test"
# Phải thấy message "Auto-updating SHA256 hash..."
```

### Hash sai?

```powershell
# Manual update
.\update-sha256.ps1

# Verify
.\verify-hash.ps1
```

### GitHub sync fail?

```powershell
# Check sync status
.\check-github-sync.ps1

# Nếu out of sync, update và push:
.\update-sha256.ps1
git add install-apps.ps1.sha256
git commit -m "chore: Fix SHA256 hash"
git push

# Wait 30 seconds cho GitHub CDN cache invalidate
# Rồi check lại
.\check-github-sync.ps1
```

---

**Tạo bởi:** Claude Code
**Mục đích:** Đảm bảo SHA256 verification luôn hoạt động 100% cho users

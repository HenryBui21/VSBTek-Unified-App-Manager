# Quick Start Guide

## 🚀 Deploy to Website

**Step 1:** Upload ONE file to your website
```
install-from-web.ps1 → https://scripts.vsbtek.com/install
```

**Step 2:** Test it
```powershell
irm https://scripts.vsbtek.com/install | iex
```

Done! ✅

## 📖 Documentation

- **[Docs/DEPLOY-TO-WEB.md](Docs/DEPLOY-TO-WEB.md)** - Detailed deployment guide
- **[Docs/CHECKLIST.md](Docs/CHECKLIST.md)** - Deployment checklist
- **[Docs/HUONG-DAN.md](Docs/HUONG-DAN.md)** - Vietnamese user guide
- **[README.md](README.md)** - Full documentation

## 🔧 Configuration

GitHub repository is already configured:
- Repository: `https://github.com/HenryBui21/VSBTek-Chocolatey-Installer`
- Configs are loaded from GitHub automatically

## 💡 Usage Examples

```powershell
# Interactive mode
irm https://scripts.vsbtek.com/install | iex

# Direct install
irm https://scripts.vsbtek.com/install | iex -Preset basic
irm https://scripts.vsbtek.com/install | iex -Preset dev
irm https://scripts.vsbtek.com/install | iex -Preset community
irm https://scripts.vsbtek.com/install | iex -Preset gaming
```

## 🔄 Updating Configs

Just push changes to GitHub - no need to re-upload anything!

```bash
git add .
git commit -m "Update app configs"
git push
```

---

**That's it! Simple and professional.** 🎯

# 🚂 Indian Railways Browser Reset Tool

A PowerShell utility to clear browser cache and fix the **"Access other apps and services on this device"** permission popup for Indian Railways websites — so it never asks again.

---

## 🌐 Target Sites

| Site | URL |
|------|-----|
| AIMS / IPAS | https://aims.indianrailways.gov.in |
| IREPS | https://www.ireps.gov.in |
| IRWCMS | https://ircep.gov.in |

---

## ❓ Problem It Solves

Every time you clear your browser or the session resets, these Railway sites show a popup:

> **www.ireps.gov.in wants to**
> _Access other apps and services on this device_
> `[ Allow ]` `[ Block ]`

This script:
- Clears cache for **Chrome** and **Edge**
- Removes stale permission entries for all 3 sites
- **Pre-sets** the `window_placement` permission to **Allow** — so the popup never appears again

---

## ⚙️ What It Does (Step by Step)

```
[0/4] Closes Chrome and Edge if they are running
[1/4] Clears Chrome Cache, Code Cache, Network Cache
[2/4] Resets + pre-approves Chrome permissions for Railway sites
[3/4] Clears Edge Cache, Code Cache, Network Cache
[4/4] Resets + pre-approves Edge permissions for Railway sites
```

A **`Preferences.backup`** file is saved automatically before any changes are made.

---

## 🚀 How to Run

### Option 1 — Right-click (Easiest)
1. Download `Reset-RailwaySites.ps1`
2. Right-click the file
3. Select **"Run with PowerShell"**

### Option 2 — From PowerShell (Recommended)
Open PowerShell as **Administrator** and run:

```powershell
# Allow script execution (one-time setup)
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# Run the script
.\Reset-RailwaySites.ps1
```

### Option 3 — One-liner (Run directly from GitHub)
```powershell
irm https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/Reset-RailwaySites.ps1 | iex
```
> ⚠️ Replace `YOUR_USERNAME/YOUR_REPO` with your actual GitHub username and repo name.

---

## 📋 Requirements

| Requirement | Details |
|-------------|---------|
| OS | Windows 10 / 11 |
| PowerShell | Version 5.1 or later (built into Windows) |
| Browsers | Google Chrome and/or Microsoft Edge |
| Permissions | Run as Administrator (recommended) |

---

## 🔒 Safety & Backup

- The script **never deletes** your bookmarks, saved passwords, or browsing history
- Only **cache folders** and **site-specific permission entries** for the 3 Railway URLs are touched
- A `Preferences.backup` file is created before every change in both browser profile folders:
  - `%LOCALAPPDATA%\Google\Chrome\User Data\Default\Preferences.backup`
  - `%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Preferences.backup`

---

## 🗂️ Files

```
📁 Repository
├── Reset-RailwaySites.ps1   ← Main PowerShell script
├── reset_railway_sites.bat  ← Legacy batch file (older version)
└── README.md
```

---

## 🛠️ Troubleshooting

| Issue | Fix |
|-------|-----|
| Script won't run | Run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` in PowerShell first |
| Chrome/Edge still shows popup | Make sure browsers were fully closed before running the script |
| Preferences.backup missing | Script may have skipped (browser profile not found) — check if Chrome/Edge is installed |
| Changes didn't apply | Run PowerShell **as Administrator** |

---

## 📝 License

MIT — Free to use and modify for personal or organizational use within Indian Railways.

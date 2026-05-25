#Requires -Version 5.1
<#
.SYNOPSIS
    Clears browser cache and resets/pre-approves permissions for Indian Railways websites.

.DESCRIPTION
    This script:
      - Closes Chrome and Edge if running
      - Clears Cache, Code Cache, and Network Cache for both browsers
      - Removes old permission entries for the 3 Railway sites
      - Pre-sets "Access other apps and services" (window_placement) to ALLOW
        so the popup never appears again

    Target Sites:
      * https://aims.indianrailways.gov.in  (AIMS / IPAS)
      * https://www.ireps.gov.in            (IREPS)
      * https://ircep.gov.in                (IRWCMS)

.NOTES
    Author  : Indian Railways IT Utility
    Version : 2.0
    Run As  : Administrator (recommended)

.EXAMPLE
    Right-click Reset-RailwaySites.ps1 -> Run with PowerShell
    OR from an elevated PowerShell prompt:
    .\Reset-RailwaySites.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

# ─────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────
$SiteKeys = @(
    'aims.indianrailways.gov.in',
    'www.ireps.gov.in',
    'ircep.gov.in'
)

# Keys used inside browser Preferences JSON for window_placement
$SitePermissionKeys = @(
    'https://aims.indianrailways.gov.in:443,*',
    'https://www.ireps.gov.in:443,*',
    'https://ircep.gov.in:443,*'
)

$PermissionTypesToClear = @(
    'cookies', 'images', 'javascript', 'notifications',
    'geolocation', 'media_stream_mic', 'media_stream_camera',
    'window_placement', 'popups', 'automatic_downloads'
)

$ChromeProfile = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
$EdgeProfile   = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"

# ─────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────
function Write-Header {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Indian Railways Sites - Reset & Fix Tool" -ForegroundColor Cyan
    Write-Host "  Sites: AIMS | IREPS | IRWCMS" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Number, [string]$Message)
    Write-Host "[$Number] $Message" -ForegroundColor Yellow
}

function Write-OK    { param([string]$m) Write-Host "        [OK]   $m" -ForegroundColor Green }
function Write-Skip  { param([string]$m) Write-Host "        [SKIP] $m" -ForegroundColor DarkGray }
function Write-Info  { param([string]$m) Write-Host "        [-]    $m" -ForegroundColor White }
function Write-Warn  { param([string]$m) Write-Host "        [WARN] $m" -ForegroundColor Magenta }

# ─────────────────────────────────────────────
# CLOSE BROWSERS
# ─────────────────────────────────────────────
function Close-Browser {
    param([string]$ProcessName, [string]$DisplayName)

    $running = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($running) {
        Write-Warn "$DisplayName is running. Closing it now..."
        Stop-Process -Name $ProcessName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-OK "$DisplayName closed."
    }
}

# ─────────────────────────────────────────────
# CLEAR BROWSER CACHE FOLDERS
# ─────────────────────────────────────────────
function Clear-BrowserCache {
    param([string]$ProfilePath, [string]$BrowserName)

    if (-not (Test-Path $ProfilePath)) {
        Write-Skip "$BrowserName profile not found. May not be installed."
        return
    }

    $cacheFolders = @('Cache', 'Code Cache', 'Network')
    foreach ($folder in $cacheFolders) {
        $fullPath = Join-Path $ProfilePath $folder
        if (Test-Path $fullPath) {
            Remove-Item -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Info "$folder cleared"
        }
    }
    Write-OK "$BrowserName cache cleared successfully."
}

# ─────────────────────────────────────────────
# RESET PERMISSIONS + PRE-SET window_placement = ALLOW
# ─────────────────────────────────────────────
function Set-BrowserPermissions {
    param([string]$ProfilePath, [string]$BrowserName)

    $PrefsFile = Join-Path $ProfilePath 'Preferences'

    if (-not (Test-Path $PrefsFile)) {
        Write-Skip "$BrowserName Preferences file not found."
        return
    }

    # Backup
    $BackupFile = "$PrefsFile.backup"
    Copy-Item -Path $PrefsFile -Destination $BackupFile -Force
    Write-Info "Backup saved: Preferences.backup"

    try {
        # Load JSON
        $json = Get-Content -Path $PrefsFile -Raw -Encoding UTF8
        $prefs = $json | ConvertFrom-Json

        # Ensure path exists
        if (-not $prefs.profile.PSObject.Properties['content_settings']) {
            $prefs.profile | Add-Member -NotePropertyName 'content_settings' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        if (-not $prefs.profile.content_settings.PSObject.Properties['exceptions']) {
            $prefs.profile.content_settings | Add-Member -NotePropertyName 'exceptions' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }

        $cs = $prefs.profile.content_settings.exceptions

        # ── Step 1: Remove old entries for all 3 sites across all permission types ──
        foreach ($permType in $PermissionTypesToClear) {
            if ($cs.PSObject.Properties[$permType]) {
                $entries = $cs.PSObject.Properties[$permType].Value
                $keys = @($entries.PSObject.Properties.Name)
                foreach ($key in $keys) {
                    foreach ($siteKey in $SiteKeys) {
                        if ($key -like "*$siteKey*") {
                            $entries.PSObject.Properties.Remove($key)
                        }
                    }
                }
            }
        }
        Write-Info "Old permission entries removed for all 3 sites."

        # ── Step 2: Pre-set window_placement = 1 (ALLOW) for all 3 sites ──
        if (-not $cs.PSObject.Properties['window_placement']) {
            $cs | Add-Member -NotePropertyName 'window_placement' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }

        $wp = $cs.window_placement
        foreach ($siteEntry in $SitePermissionKeys) {
            $permEntry = [PSCustomObject]@{
                last_modified = '13000000000000000'
                setting       = 1   # 1 = Allow, 2 = Block
            }
            $wp | Add-Member -NotePropertyName $siteEntry -NotePropertyValue $permEntry -Force
        }
        Write-Info "window_placement set to ALLOW for all 3 sites."

        # ── Save ──
        $prefs | ConvertTo-Json -Depth 100 | Set-Content -Path $PrefsFile -Encoding UTF8
        Write-OK "$BrowserName permissions fixed — 'Access to apps/services' = ALLOWED."

    } catch {
        Write-Warn "Could not update $BrowserName Preferences: $_"
        Write-Info "Restoring backup..."
        Copy-Item -Path $BackupFile -Destination $PrefsFile -Force
    }
}

# ─────────────────────────────────────────────
# SUMMARY FOOTER
# ─────────────────────────────────────────────
function Write-Summary {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  ALL DONE! Summary" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Cache Cleared       : Chrome & Edge" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Permissions fixed for:" -ForegroundColor Green
    Write-Host "    * https://aims.indianrailways.gov.in" -ForegroundColor White
    Write-Host "    * https://www.ireps.gov.in" -ForegroundColor White
    Write-Host "    * https://ircep.gov.in" -ForegroundColor White
    Write-Host ""
    Write-Host "  [ALLOWED] Access to other apps & services" -ForegroundColor Green
    Write-Host "            No more Allow/Block popup!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Backup : Preferences.backup (Chrome & Edge)" -ForegroundColor DarkGray
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Open Chrome or Edge and visit the sites." -ForegroundColor Yellow
    Write-Host "  Enjoy Work!" -ForegroundColor Yellow
    Write-Host ""
}

# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────
Write-Header

# Step 0 — Close browsers
Write-Step "0/4" "Checking for running browsers..."
Close-Browser -ProcessName 'chrome'  -DisplayName 'Google Chrome'
Close-Browser -ProcessName 'msedge'  -DisplayName 'Microsoft Edge'
Write-Host ""

# Step 1 — Chrome cache
Write-Step "1/4" "Clearing Google Chrome cache..."
Clear-BrowserCache -ProfilePath $ChromeProfile -BrowserName 'Chrome'
Write-Host ""

# Step 2 — Chrome permissions
Write-Step "2/4" "Fixing Chrome permissions for Railway sites..."
Set-BrowserPermissions -ProfilePath $ChromeProfile -BrowserName 'Chrome'
Write-Host ""

# Step 3 — Edge cache
Write-Step "3/4" "Clearing Microsoft Edge cache..."
Clear-BrowserCache -ProfilePath $EdgeProfile -BrowserName 'Edge'
Write-Host ""

# Step 4 — Edge permissions
Write-Step "4/4" "Fixing Edge permissions for Railway sites..."
Set-BrowserPermissions -ProfilePath $EdgeProfile -BrowserName 'Edge'

Write-Summary

Read-Host "Press Enter to exit"

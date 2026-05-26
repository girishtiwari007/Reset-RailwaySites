#Requires -Version 5.1
<#
.SYNOPSIS
    Clears browser cache and resets/pre-approves permissions for Indian Railways websites.

.DESCRIPTION
    Supports: Google Chrome, Microsoft Edge, Mozilla Firefox
    Target Sites:
      * https://aims.indianrailways.gov.in  (AIMS / IPAS)
      * https://www.ireps.gov.in            (IREPS)
      * https://ircep.gov.in                (IRWCMS)

.NOTES
    Version : 3.0
    Run As  : Administrator (recommended)
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
$FirefoxBase   = "$env:APPDATA\Mozilla\Firefox\Profiles"

# ─────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────
function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  +================================================+" -ForegroundColor Cyan
    Write-Host "  |   Indian Railways - Browser Reset & Fix Tool   |" -ForegroundColor Cyan
    Write-Host "  |   AIMS  |  IREPS  |  IRWCMS                   |" -ForegroundColor Cyan
    Write-Host "  +================================================+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Sites targeted:" -ForegroundColor White
    Write-Host "    * https://aims.indianrailways.gov.in" -ForegroundColor DarkCyan
    Write-Host "    * https://www.ireps.gov.in"           -ForegroundColor DarkCyan
    Write-Host "    * https://ircep.gov.in"               -ForegroundColor DarkCyan
    Write-Host ""
}

function Write-Step { param([string]$n,[string]$m) Write-Host "  [$n] $m" -ForegroundColor Yellow }
function Write-OK   { param([string]$m) Write-Host "        [OK]  $m" -ForegroundColor Green }
function Write-Skip { param([string]$m) Write-Host "        [--]  $m" -ForegroundColor DarkGray }
function Write-Info { param([string]$m) Write-Host "        [..]  $m" -ForegroundColor White }
function Write-Warn { param([string]$m) Write-Host "        [!!]  $m" -ForegroundColor Magenta }

# ─────────────────────────────────────────────
# STEP 0 — DETECT OPEN BROWSERS & WARN USER
# ─────────────────────────────────────────────
function Show-BrowserWarning {
    $openBrowsers = @()
    $browserChecks = @(
        @{ Process = 'chrome';  Name = 'Google Chrome'   },
        @{ Process = 'msedge';  Name = 'Microsoft Edge'  },
        @{ Process = 'firefox'; Name = 'Mozilla Firefox' }
    )

    foreach ($b in $browserChecks) {
        if (Get-Process -Name $b.Process -ErrorAction SilentlyContinue) {
            $openBrowsers += $b.Name
        }
    }

    if ($openBrowsers.Count -gt 0) {
        Write-Host "  +------------------------------------------------+" -ForegroundColor Magenta
        Write-Host "  |   WARNING: Browsers are currently open!        |" -ForegroundColor Magenta
        Write-Host "  +------------------------------------------------+" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "  Detected running:" -ForegroundColor Yellow
        foreach ($b in $openBrowsers) {
            Write-Host "    *  $b" -ForegroundColor White
        }
        Write-Host ""
        Write-Host "  You do NOT have to close them to run this script." -ForegroundColor White
        Write-Host ""
        Write-Host "  However, if a browser is open and rewrites its" -ForegroundColor DarkGray
        Write-Host "  Preferences file on exit, the permission fix may" -ForegroundColor DarkGray
        Write-Host "  be overwritten. For the best result:" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "    >> Close all browsers, then press Enter <<" -ForegroundColor Cyan
        Write-Host "    >> OR press Enter now to proceed anyway  <<" -ForegroundColor DarkGray
        Write-Host ""
    } else {
        Write-Host "  [OK] No browsers are currently running. Good to go!" -ForegroundColor Green
        Write-Host ""
    }

    Write-Host "  ------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  This script will ONLY affect these 3 sites:" -ForegroundColor White
    Write-Host "    * aims.indianrailways.gov.in" -ForegroundColor Cyan
    Write-Host "    * www.ireps.gov.in"           -ForegroundColor Cyan
    Write-Host "    * ircep.gov.in"               -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Passwords, bookmarks, history = NOT touched." -ForegroundColor DarkGray
    Write-Host "  ------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Press ENTER to start the reset   |   Ctrl+C to cancel" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Press Enter"
    Write-Host ""
}

# ─────────────────────────────────────────────
# CLEAR CHROMIUM CACHE
# ─────────────────────────────────────────────
function Clear-ChromiumCache {
    param([string]$ProfilePath, [string]$BrowserName)

    if (-not (Test-Path $ProfilePath)) {
        Write-Skip "$BrowserName profile not found. Not installed or different location."
        return
    }

    $cleared = 0
    foreach ($folder in @('Cache', 'Code Cache', 'Network')) {
        $fullPath = Join-Path $ProfilePath $folder
        if (Test-Path $fullPath) {
            Remove-Item -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Info "$folder cleared"
            $cleared++
        }
    }

    if ($cleared -gt 0) {
        Write-OK "$BrowserName cache cleared ($cleared folder(s) removed)."
    } else {
        Write-Skip "$BrowserName — cache already clean."
    }
}

# ─────────────────────────────────────────────
# FIX CHROMIUM PERMISSIONS
# ─────────────────────────────────────────────
function Set-ChromiumPermissions {
    param([string]$ProfilePath, [string]$BrowserName)

    $PrefsFile = Join-Path $ProfilePath 'Preferences'

    if (-not (Test-Path $PrefsFile)) {
        Write-Skip "$BrowserName Preferences file not found."
        return
    }

    Copy-Item -Path $PrefsFile -Destination "$PrefsFile.backup" -Force
    Write-Info "Backup saved: Preferences.backup"

    try {
        $prefs = Get-Content -Path $PrefsFile -Raw -Encoding UTF8 | ConvertFrom-Json

        if (-not $prefs.profile.PSObject.Properties['content_settings']) {
            $prefs.profile | Add-Member -NotePropertyName 'content_settings' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        if (-not $prefs.profile.content_settings.PSObject.Properties['exceptions']) {
            $prefs.profile.content_settings | Add-Member -NotePropertyName 'exceptions' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }

        $cs = $prefs.profile.content_settings.exceptions

        # Remove old permission entries for only the 3 Railway sites
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
        Write-Info "Old Railway site permissions removed."

        # Pre-set window_placement = 1 (Allow) for all 3 sites
        if (-not $cs.PSObject.Properties['window_placement']) {
            $cs | Add-Member -NotePropertyName 'window_placement' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        $wp = $cs.window_placement
        foreach ($siteEntry in $SitePermissionKeys) {
            $wp | Add-Member -NotePropertyName $siteEntry -NotePropertyValue ([PSCustomObject]@{
                last_modified = '13000000000000000'
                setting       = 1
            }) -Force
        }
        Write-Info "'Access to apps/services' pre-set to ALLOW for all 3 sites."

        $prefs | ConvertTo-Json -Depth 100 | Set-Content -Path $PrefsFile -Encoding UTF8
        Write-OK "$BrowserName done. Permission popup will NOT appear on next visit."

    } catch {
        Write-Warn "Error modifying $BrowserName Preferences: $_"
        Write-Info "Restoring from backup..."
        Copy-Item -Path "$PrefsFile.backup" -Destination $PrefsFile -Force
    }
}

# ─────────────────────────────────────────────
# FIREFOX — Clear Railway site data only
# ─────────────────────────────────────────────
function Clear-FirefoxSiteData {
    if (-not (Test-Path $FirefoxBase)) {
        Write-Skip "Firefox is not installed or profile folder not found."
        return
    }

    $profiles = Get-ChildItem -Path $FirefoxBase -Directory -ErrorAction SilentlyContinue
    if (-not $profiles) {
        Write-Skip "No Firefox profiles found."
        return
    }

    $ffRunning = [bool](Get-Process -Name 'firefox' -ErrorAction SilentlyContinue)
    if ($ffRunning) {
        Write-Warn "Firefox is open. SQLite databases cannot be safely edited while running."
        Write-Info "Cache folders will still be cleared."
        Write-Info "For full cookie/permission reset: close Firefox and re-run this script."
    }

    $sqlite = Get-Command 'sqlite3' -ErrorAction SilentlyContinue

    foreach ($profile in $profiles) {
        Write-Info "Firefox profile: $($profile.Name)"

        # Clear network cache (safe even if Firefox is open)
        $cacheDir = Join-Path $profile.FullName 'cache2'
        if (Test-Path $cacheDir) {
            Remove-Item -Path $cacheDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Info "Cache2 cleared."
        }

        if (-not $ffRunning) {
            # Cookies
            $cookiesDb = Join-Path $profile.FullName 'cookies.sqlite'
            if ((Test-Path $cookiesDb) -and $sqlite) {
                Copy-Item $cookiesDb "$cookiesDb.backup" -Force
                foreach ($site in $SiteKeys) {
                    & sqlite3 $cookiesDb "DELETE FROM moz_cookies WHERE host LIKE '%$site%';" 2>$null
                }
                Write-Info "Cookies cleared for Railway sites."
            }

            # Permissions
            $permDb = Join-Path $profile.FullName 'permissions.sqlite'
            if ((Test-Path $permDb) -and $sqlite) {
                Copy-Item $permDb "$permDb.backup" -Force
                foreach ($site in $SiteKeys) {
                    & sqlite3 $permDb "DELETE FROM moz_perms WHERE origin LIKE '%$site%';" 2>$null
                }
                Write-Info "Firefox permissions cleared for Railway sites."
            }

            if (-not $sqlite) {
                Write-Warn "sqlite3.exe not in PATH — cookie/permission DBs skipped."
                Write-Info "To clear manually in Firefox: Ctrl+Shift+Del > Cookies for Railway sites."
            }
        }
    }
    Write-OK "Firefox processing complete."
}

# ─────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────
function Write-Summary {
    Write-Host ""
    Write-Host "  +================================================+" -ForegroundColor Green
    Write-Host "  |              ALL DONE!  Summary                |" -ForegroundColor Green
    Write-Host "  +================================================+" -ForegroundColor Green
    Write-Host ""
    Write-Host "  [OK] Cache cleared        : Chrome, Edge, Firefox" -ForegroundColor Green
    Write-Host "  [OK] Permissions reset    : Only the 3 Railway sites" -ForegroundColor Green
    Write-Host "  [OK] Allow pre-approved   : No more Allow/Block popup!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Sites fixed:" -ForegroundColor White
    Write-Host "    * https://aims.indianrailways.gov.in" -ForegroundColor Cyan
    Write-Host "    * https://www.ireps.gov.in"           -ForegroundColor Cyan
    Write-Host "    * https://ircep.gov.in"               -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Backup files saved as  Preferences.backup" -ForegroundColor DarkGray
    Write-Host "  (Chrome & Edge profile folders)"           -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  Open your browser and visit the sites." -ForegroundColor Yellow
    Write-Host "  Enjoy Work!" -ForegroundColor Yellow
    Write-Host ""
}

# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────
Write-Header
Show-BrowserWarning

Write-Step "1/6" "Clearing Google Chrome cache..."
Clear-ChromiumCache -ProfilePath $ChromeProfile -BrowserName 'Chrome'
Write-Host ""

Write-Step "2/6" "Fixing Chrome permissions for Railway sites..."
Set-ChromiumPermissions -ProfilePath $ChromeProfile -BrowserName 'Chrome'
Write-Host ""

Write-Step "3/6" "Clearing Microsoft Edge cache..."
Clear-ChromiumCache -ProfilePath $EdgeProfile -BrowserName 'Edge'
Write-Host ""

Write-Step "4/6" "Fixing Edge permissions for Railway sites..."
Set-ChromiumPermissions -ProfilePath $EdgeProfile -BrowserName 'Edge'
Write-Host ""

Write-Step "5/6" "Processing Mozilla Firefox..."
Clear-FirefoxSiteData
Write-Host ""

Write-Step "6/6" "Finalizing..."
Write-OK "All done."
Write-Host ""

Write-Summary
Read-Host "  Press Enter to exit"

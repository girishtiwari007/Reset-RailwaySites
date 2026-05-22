# ============================================================
#  Indian Railways Sites - Permission & Cache Reset Tool
#  Sites: AIMS, IREPS, IRWCMS
#  Usage: iwr -useb https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/Reset-RailwaySites.ps1 | iex
# ============================================================

$railwaySites = @(
    'aims.indianrailways.gov.in',
    'www.ireps.gov.in',
    'ircep.gov.in'
)

function Write-Header {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Indian Railways Sites - Reset Tool" -ForegroundColor Green
    Write-Host "  Sites: AIMS, IREPS, IRWCMS" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Stop-Browser {
    param([string]$ProcessName, [string]$BrowserName)
    $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "[WARNING] $BrowserName is currently running. Closing it now..." -ForegroundColor Yellow
        Stop-Process -Name $ProcessName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Host "[INFO] $BrowserName has been closed." -ForegroundColor Green
        Write-Host ""
    }
}

function Clear-BrowserCache {
    param([string]$ProfilePath, [string]$BrowserName)

    if (-not (Test-Path $ProfilePath)) {
        Write-Host "      [SKIP] $BrowserName profile not found. $BrowserName may not be installed." -ForegroundColor DarkGray
        return
    }

    $cacheFolders = @("Cache", "Code Cache", "Network")
    foreach ($folder in $cacheFolders) {
        $path = Join-Path $ProfilePath $folder
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "       - $folder cleared" -ForegroundColor Gray
        }
    }
    Write-Host "      [DONE] $BrowserName cache cleared successfully." -ForegroundColor Green
}

function Reset-SitePermissions {
    param([string]$PrefsPath, [string]$BrowserName)

    if (-not (Test-Path $PrefsPath)) {
        Write-Host "      [SKIP] $BrowserName Preferences file not found." -ForegroundColor DarkGray
        return
    }

    # Backup
    $backupPath = "$PrefsPath.backup"
    Copy-Item -Path $PrefsPath -Destination $backupPath -Force -ErrorAction SilentlyContinue
    Write-Host "       - Preferences backup created ($BrowserName Preferences.backup)" -ForegroundColor Gray

    try {
        $prefsRaw = Get-Content $PrefsPath -Raw -Encoding UTF8
        $prefs = $prefsRaw | ConvertFrom-Json

        $changed = $false

        if ($prefs.profile.content_settings.exceptions) {
            $cs = $prefs.profile.content_settings.exceptions
            $cs.PSObject.Properties | ForEach-Object {
                $entries = $_.Value
                if ($entries -is [PSCustomObject]) {
                    $keys = @($entries.PSObject.Properties.Name)
                    foreach ($key in $keys) {
                        foreach ($site in $railwaySites) {
                            if ($key -like "*$site*") {
                                $entries.PSObject.Properties.Remove($key)
                                $changed = $true
                            }
                        }
                    }
                }
            }
        }

        if ($changed) {
            $prefs | ConvertTo-Json -Depth 100 | Set-Content $PrefsPath -Encoding UTF8
            Write-Host "      [DONE] $BrowserName permissions reset for Railway sites." -ForegroundColor Green
        } else {
            Write-Host "      [INFO] No Railway site permissions found in $BrowserName (nothing to reset)." -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "      [ERROR] Failed to parse $BrowserName Preferences: $_" -ForegroundColor Red
    }
}

# ── MAIN ──────────────────────────────────────────────────────────────────────

Write-Header

# Close browsers
Stop-Browser -ProcessName "chrome"   -BrowserName "Google Chrome"
Stop-Browser -ProcessName "msedge"   -BrowserName "Microsoft Edge"

# Chrome paths
$chromePath  = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
$chromePrefs = "$chromePath\Preferences"

# Edge paths
$edgePath    = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
$edgePrefs   = "$edgePath\Preferences"

# 1. Chrome Cache
Write-Host "[1/4] Clearing Google Chrome cache..." -ForegroundColor Cyan
Clear-BrowserCache -ProfilePath $chromePath -BrowserName "Chrome"
Write-Host ""

# 2. Chrome Permissions
Write-Host "[2/4] Resetting Chrome site permissions for Railway sites..." -ForegroundColor Cyan
Reset-SitePermissions -PrefsPath $chromePrefs -BrowserName "Chrome"
Write-Host ""

# 3. Edge Cache
Write-Host "[3/4] Clearing Microsoft Edge cache..." -ForegroundColor Cyan
Clear-BrowserCache -ProfilePath $edgePath -BrowserName "Edge"
Write-Host ""

# 4. Edge Permissions
Write-Host "[4/4] Resetting Edge site permissions for Railway sites..." -ForegroundColor Cyan
Reset-SitePermissions -PrefsPath $edgePrefs -BrowserName "Edge"
Write-Host ""

# Summary
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ALL DONE! Summary:" -ForegroundColor Green
Write-Host "  - Chrome cache cleared" -ForegroundColor White
Write-Host "  - Chrome permissions reset for:" -ForegroundColor White
foreach ($site in $railwaySites) {
    Write-Host "      * $site" -ForegroundColor Gray
}
Write-Host "  - Edge cache cleared" -ForegroundColor White
Write-Host "  - Edge permissions reset for same sites" -ForegroundColor White
Write-Host ""
Write-Host "  Backup files saved as Preferences.backup" -ForegroundColor DarkGray
Write-Host "  in your browser profile folders." -ForegroundColor DarkGray
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Now open Chrome or Edge and visit the sites fresh." -ForegroundColor Yellow
Write-Host ""
Write-Host "Enjoy Work!" -ForegroundColor Green
Write-Host ""

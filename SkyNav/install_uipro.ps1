# Install ui-ux-pro-max skill for Claude Code
Write-Host "=== Installing ui-ux-pro-max ===" -ForegroundColor Cyan

# Find npm
$npm = (Get-Command npm -ErrorAction SilentlyContinue)?.Source
if (-not $npm) {
    $candidates = @(
        "C:\Program Files\nodejs\npm.cmd",
        "C:\Program Files (x86)\nodejs\npm.cmd",
        "$env:LOCALAPPDATA\Programs\nodejs\npm.cmd"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $npm = $c; break }
    }
}
if (-not $npm) {
    Write-Error "npm not found. Install Node.js from https://nodejs.org"
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "npm: $npm" -ForegroundColor Green

# Install uipro-cli
Write-Host "`n[1/2] npm install -g uipro-cli" -ForegroundColor Yellow
& $npm install -g uipro-cli
if ($LASTEXITCODE -ne 0) {
    Write-Error "npm install failed (exit code $LASTEXITCODE)"
    Read-Host "Press Enter to exit"
    exit 1
}

# Find uipro (npm global bin dir)
$npmBin = & $npm bin -g 2>$null
if (-not $npmBin) { $npmBin = "$env:APPDATA\npm" }
$uipro = Join-Path $npmBin "uipro.cmd"
if (-not (Test-Path $uipro)) { $uipro = Join-Path $npmBin "uipro" }
Write-Host "uipro: $uipro" -ForegroundColor Green

# Run uipro init
Write-Host "`n[2/2] uipro init --ai claude --global" -ForegroundColor Yellow
& $uipro init --ai claude --global
if ($LASTEXITCODE -ne 0) {
    Write-Warning "uipro init exited with code $LASTEXITCODE"
}

# Verify
$skillPath = "$env:USERPROFILE\.claude\skills\ui-ux-pro-max"
if (Test-Path $skillPath) {
    Write-Host "`nSUCCESS: $skillPath" -ForegroundColor Green
} else {
    Write-Warning "Not found at $skillPath - check above for errors"
    Write-Host "Skills folder contents:"
    Get-ChildItem "$env:USERPROFILE\.claude\skills\" | Format-Table Name, LastWriteTime
}

Read-Host "`nPress Enter to close"

@echo off
echo ==========================================
echo  Installing Claude Plugins
echo ==========================================
echo.

REM ---- 1. stop-slop (skill) ----
echo [1/5] Installing stop-slop skill...
if not exist "%USERPROFILE%\.claude\skills" mkdir "%USERPROFILE%\.claude\skills"
if exist "%USERPROFILE%\.claude\skills\stop-slop" (
    cd /d "%USERPROFILE%\.claude\skills\stop-slop"
    git pull
) else (
    git clone https://github.com/hardikpandya/stop-slop.git "%USERPROFILE%\.claude\skills\stop-slop"
)
echo.

REM ---- 2. ui-ux-pro-max (npm CLI) ----
echo [2/5] Installing ui-ux-pro-max...
call npm install -g uipro-cli
call uipro init --ai claude --global
echo.

REM ---- 3. superpowers (clone) ----
echo [3/5] Cloning superpowers...
if not exist "%USERPROFILE%\.claude\plugins" mkdir "%USERPROFILE%\.claude\plugins"
if exist "%USERPROFILE%\.claude\plugins\superpowers" (
    cd /d "%USERPROFILE%\.claude\plugins\superpowers"
    git pull
) else (
    git clone https://github.com/obra/superpowers.git "%USERPROFILE%\.claude\plugins\superpowers"
)
echo.

REM ---- 4. claude-council (clone) ----
echo [4/5] Cloning claude-council...
if exist "%USERPROFILE%\.claude\plugins\claude-council" (
    cd /d "%USERPROFILE%\.claude\plugins\claude-council"
    git pull
) else (
    git clone https://github.com/hex/claude-council.git "%USERPROFILE%\.claude\plugins\claude-council"
)
echo.

REM ---- 5. playwright-mcp (MCP config) ----
echo [5/5] Configuring playwright-mcp...
set CONFIG_DIR=%APPDATA%\Claude
set CONFIG_FILE=%CONFIG_DIR%\claude_desktop_config.json
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%"
powershell -NoProfile -Command "$p='%CONFIG_FILE%'; if(Test-Path $p){$c=Get-Content $p -Raw|ConvertFrom-Json}else{$c=[PSCustomObject]@{}}; if(-not $c.PSObject.Properties['mcpServers']){$c|Add-Member -NotePropertyName mcpServers -NotePropertyValue ([PSCustomObject]@{})}; $pw=[PSCustomObject]@{command='npx';args=@('@playwright/mcp@latest')}; $c.mcpServers|Add-Member -NotePropertyName playwright -NotePropertyValue $pw -Force; $c|ConvertTo-Json -Depth 10|Set-Content $p -Encoding UTF8; Write-Host 'playwright-mcp configured.'"
echo.

echo ==========================================
echo  Done! Files installed to:
echo    Skills:  %USERPROFILE%\.claude\skills\
echo    Plugins: %USERPROFILE%\.claude\plugins\
echo    MCP:     %APPDATA%\Claude\claude_desktop_config.json
echo.
echo  For superpowers + claude-council, also run
echo  these commands inside Claude Code:
echo    /plugin marketplace add obra/superpowers-marketplace
echo    /plugin install superpowers@superpowers-marketplace
echo    /plugin marketplace add hex/claude-marketplace
echo    /plugin install claude-council
echo ==========================================
pause

@echo off
cd /d "C:\Users\Weston\Desktop\SkyNav"
del /f ".git\index.lock" 2>nul
git add -A
git commit -m "feat: UI overhaul, iOS 26 liquid glass, Flighty features, website"
echo.
echo Done! Press any key to close.
pause

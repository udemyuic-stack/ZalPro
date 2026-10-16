@echo off
chcp 65001 >nul
title Diamond - Firebase ga joylash
cd /d "%~dp0"
echo.
echo   Diamond - yuklab olish sahifasini yangilash
echo   ==========================================
echo.
echo   Birinchi marta brauzer ochiladi - Google akkauntingizni
echo   (loyiha egasining Google akkauntini) tanlang va ruxsat bering.
echo.
pause
powershell -ExecutionPolicy Bypass -File "%~dp0deploy.ps1"
echo.
echo   Tugadi. Oynani yopishingiz mumkin.
pause

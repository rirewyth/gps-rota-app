# ROTA+ EMNİYETTEYİM (v1.2.0 Build 145) - Temiz Google Play AAB Derleme Betiği
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location "$scriptDir\mountaineering_app"

$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "C:\gps-rota-app-main\flutter\bin;$env:JAVA_HOME\bin;" + $env:PATH

Write-Host "Önbellek temizleniyor (flutter clean)..." -ForegroundColor Yellow
& "C:\gps-rota-app-main\flutter\bin\flutter.bat" clean

Write-Host "Paketler alınıyor..." -ForegroundColor Cyan
& "C:\gps-rota-app-main\flutter\bin\flutter.bat" pub get

Write-Host "Google Play AAB derleniyor..." -ForegroundColor Cyan
& "C:\gps-rota-app-main\flutter\bin\flutter.bat" build aab --release

if ($LASTEXITCODE -eq 0) {
    $aabPath = "$scriptDir\mountaineering_app\build\app\outputs\bundle\release\app-release.aab"
    if (-not (Test-Path $aabPath)) {
        $aab = Get-ChildItem -Path "$scriptDir\mountaineering_app\build" -Recurse -Filter "app-release.aab" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($aab) { $aabPath = $aab.FullName }
    }

    if (Test-Path $aabPath) {
        $dest = "$scriptDir\RotaPlus_v1.2.0_release.aab"
        Copy-Item $aabPath $dest -Force
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host "BAŞARILI: Temiz Google Play AAB oluşturuldu!" -ForegroundColor Green
        Write-Host "Konum: $dest" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green
    } else {
        Write-Warning "AAB üretildi ancak dosya konumu saptanamadı."
    }
} else {
    Write-Error "AAB derleme işlemi başarısız oldu (Hata Kodu: $LASTEXITCODE)."
}

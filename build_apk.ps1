# ROTA+ EMNİYETTEYİM (v1.2.0 Build 145) - Release APK Derleme Betiği
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location "$scriptDir\mountaineering_app"

$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "C:\gps-rota-app-main\flutter\bin;$env:JAVA_HOME\bin;" + $env:PATH

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "ROTA+ EMNİYETTEYİM - ANDROID APK DERLEME" -ForegroundColor Cyan
Write-Host "Sürüm: 1.2.0 | Build: 145" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan

Write-Host "Paketler güncelleniyor (flutter pub get)..."
& "C:\gps-rota-app-main\flutter\bin\flutter.bat" pub get

Write-Host "Release APK derleniyor..."
& "C:\gps-rota-app-main\flutter\bin\flutter.bat" build apk --release

if ($LASTEXITCODE -eq 0) {
    $apkPath = "$scriptDir\mountaineering_app\build\app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path $apkPath)) {
        $apk = Get-ChildItem -Path "$scriptDir\mountaineering_app\build" -Recurse -Filter "app-release.apk" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($apk) { $apkPath = $apk.FullName }
    }

    if (Test-Path $apkPath) {
        $dest = "$scriptDir\RotaPlus_v1.2.0_release.apk"
        Copy-Item $apkPath $dest -Force
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host "BAŞARILI: Release APK oluşturuldu!" -ForegroundColor Green
        Write-Host "Konum: $dest" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green
    } else {
        Write-Warning "APK üretildi ancak dosya konumu saptanamadı."
    }
} else {
    Write-Error "APK derleme işlemi başarısız oldu (Hata Kodu: $LASTEXITCODE)."
}

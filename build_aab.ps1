# ROTA+ EMNİYETTEYİM (v1.2.0 Build 145) - Google Play Store AAB Derleme Betiği
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location "$scriptDir\mountaineering_app"

$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "C:\gps-rota-app-main\flutter\bin;$env:JAVA_HOME\bin;" + $env:PATH

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "ROTA+ EMNİYETTEYİM - GOOGLE PLAY AAB DERLEME" -ForegroundColor Cyan
Write-Host "Sürüm: 1.2.0 | Build: 145" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan

Write-Host "Paketler güncelleniyor (flutter pub get)..."
& "C:\gps-rota-app-main\flutter\bin\flutter.bat" pub get

Write-Host "Production AAB derleniyor..."
& "C:\gps-rota-app-main\flutter\bin\flutter.bat" build aab --release

$aabPath = "$scriptDir\mountaineering_app\build\app\outputs\bundle\release\app-release.aab"
if (-not (Test-Path $aabPath)) {
    $aabPath = "$scriptDir\mountaineering_app\android\app\build\outputs\bundle\release\app-release.aab"
}
if (-not (Test-Path $aabPath)) {
    $found = Get-ChildItem -Path "$scriptDir\mountaineering_app\android\app\build\outputs" -Recurse -Filter "app-release.aab" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $aabPath = $found.FullName }
}

if (Test-Path $aabPath) {
    $dest = "$scriptDir\RotaPlus_v1.2.0_release.aab"
    Copy-Item $aabPath $dest -Force
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "BAŞARILI: Google Play Store AAB oluşturuldu!" -ForegroundColor Green
    Write-Host "Dosya: $dest" -ForegroundColor Green
    $sizeMb = [math]::Round((Get-Item $dest).Length / 1MB, 2)
    Write-Host "Boyut: $sizeMb MB" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
} else {
    Write-Error "AAB derleme işlemi başarısız oldu: AAB dosyası bulunamadı."
}

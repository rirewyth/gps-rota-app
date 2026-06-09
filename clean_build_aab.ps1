Set-Location "c:\213\mountaineering_app"
$env:PATH = "C:\flutter\bin;" + $env:PATH
Write-Host "Cleaning..."
& "C:\flutter\bin\flutter.bat" clean
Write-Host "Building AAB..."
& "C:\flutter\bin\flutter.bat" build aab --release
if ($LASTEXITCODE -eq 0) {
    $aab = Get-ChildItem -Path "build\app\outputs\bundle\release" -Recurse -Filter "app-release.aab" | Select-Object -First 1
    if ($aab) {
        Copy-Item $aab.FullName "c:\213\acildurumapp9.aab" -Force
        Write-Host "BASARILI: c:\213\acildurumapp9.aab"
    } else {
        Write-Host "HATA: AAB dosyasi bulunamadi."
    }
} else {
    Write-Host "HATA: Build basarisiz oldu."
}

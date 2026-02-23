# Iniciar BsL
Clear-Host
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "        BsL - Basic Language AvaStr             " -ForegroundColor Cyan
Write-Host "    Programacion Visual para Windows            " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que el archivo principal existe
if (-not (Test-Path ".\BsL.ps1")) {
    Write-Host "Error: No se encuentra el archivo BsL.ps1" -ForegroundColor Red
    Write-Host "Asegurate de estar en la carpeta correcta" -ForegroundColor Yellow
    Read-Host "Presiona Enter para salir"
    exit
}

Write-Host "Iniciando BsL IDE..." -ForegroundColor Green
Write-Host ""

# Ejecutar el IDE
& ".\BsL.ps1"

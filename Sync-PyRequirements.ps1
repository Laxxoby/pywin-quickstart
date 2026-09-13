<#
.SYNOPSIS
    Detecta los imports de tu código, actualiza requirements.txt e instala automáticamente
    las librerías necesarias en el venv del proyecto.

.DESCRIPTION
    Sync-PyRequirements.ps1 cierra el ciclo de "escribo código -> instalo lo que use":
    1. Usa pipreqs (dentro del venv del proyecto) para escanear los .py y detectar qué
       librerías se están importando, y regenera requirements.txt con esas librerías y
       sus versiones más recientes en PyPI (pipreqs no necesita que las librerías ya
       estén instaladas para detectarlas, solo lee el código).
    2. Instala en el venv, con pip, todo lo que quedó listado en requirements.txt.

    Así ya no hace falta instalar cada librería a mano con "pip install algo": basta con
    escribir el import en el código y correr este script.

.PARAMETER Path
    Ruta del proyecto (donde está la carpeta venv). Por defecto, el directorio actual.

.EXAMPLE
    Sync-PyRequirements.ps1

.EXAMPLE
    Sync-PyRequirements.ps1 -Path "D:\Proyectos\mi-proyecto"

.NOTES
    Requiere que el proyecto ya tenga una carpeta 'venv' (creada por ejemplo con New-PyProject.ps1).
    Ver documentación completa en DOCUMENTACION-New-PyProject.md
#>

param(
    [string]$Path = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host ">> $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "AVISO: $msg" -ForegroundColor Yellow }

$venvPath = Join-Path $Path "venv"
$venvPip = Join-Path $venvPath "Scripts\pip.exe"
$venvPipreqs = Join-Path $venvPath "Scripts\pipreqs.exe"
$reqPath = Join-Path $Path "requirements.txt"

if (-not (Test-Path $venvPath)) {
    Write-Error "No se encontró la carpeta 'venv' en '$Path'. ¿Corriste New-PyProject.ps1 aquí?"
    exit 1
}

if (-not (Test-Path $venvPipreqs)) {
    Write-Step "pipreqs no está instalado en el venv, instalándolo primero"
    & $venvPip install pipreqs --quiet
    Write-Ok "pipreqs instalado"
}

Write-Step "Escaneando el código en busca de imports y actualizando requirements.txt"
Push-Location $Path
try {
    & $venvPipreqs . --force
} finally {
    Pop-Location
}
Write-Ok "requirements.txt actualizado según los imports detectados"

if ((Test-Path $reqPath) -and ((Get-Content $reqPath -Raw).Trim().Length -gt 0)) {
    Write-Step "Instalando en el venv las librerías detectadas"
    & $venvPip install -r $reqPath
    Write-Ok "Librerías instaladas en el venv"
} else {
    Write-Warn2 "requirements.txt quedó vacío: no se detectaron imports externos todavía."
}

Write-Host ""
Write-Ok "Sincronización completa."

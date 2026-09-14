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
    Ruta del proyecto (donde está la carpeta del entorno virtual). Por defecto, el directorio actual.

.EXAMPLE
    Sync-PyRequirements.ps1

.EXAMPLE
    Sync-PyRequirements.ps1 -Path "D:\Proyectos\mi-proyecto"

.NOTES
    Requiere que el proyecto ya tenga un entorno virtual, en una carpeta llamada '.venv' (nombre
    actual usado por New-PyProject.ps1) o 'venv' (nombre usado por versiones anteriores); detecta
    cualquiera de las dos automáticamente.
    Ver documentación completa en DOCUMENTACION-New-PyProject.md
#>

param(
    [string]$Path = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host ">> $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "AVISO: $msg" -ForegroundColor Yellow }

# Acepta tanto ".venv" (nombre actual que usa New-PyProject.ps1) como "venv"
# (nombre usado por versiones anteriores), para no romper proyectos ya creados.
$dotVenvPath = Join-Path $Path ".venv"
$venvPath    = Join-Path $Path "venv"

if (Test-Path $dotVenvPath) {
    $activeVenvPath = $dotVenvPath
    $activeVenvName = ".venv"
} elseif (Test-Path $venvPath) {
    $activeVenvPath = $venvPath
    $activeVenvName = "venv"
} else {
    Write-Error "No se encontró ninguna carpeta de entorno virtual ('.venv' o 'venv') en '$Path'. ¿Corriste New-PyProject.ps1 aquí?"
    exit 1
}
Write-Ok "Entorno virtual detectado: $activeVenvName"

$venvPython = Join-Path $activeVenvPath "Scripts\python.exe"
$venvPipreqs = Join-Path $activeVenvPath "Scripts\pipreqs.exe"
$reqPath = Join-Path $Path "requirements.txt"

if (-not (Test-Path $venvPipreqs)) {
    Write-Step "pipreqs no está instalado en el venv, instalándolo primero"
    & $venvPython -m pip install pipreqs --quiet
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
    & $venvPython -m pip install -r $reqPath
    Write-Ok "Librerías instaladas en el venv"
} else {
    Write-Warn2 "requirements.txt quedó vacío: no se detectaron imports externos todavía."
}

Write-Host ""
Write-Ok "Sincronización completa."

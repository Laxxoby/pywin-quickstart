<#
.SYNOPSIS
    Instala los comandos "newpy", "syncpy" y "checkpy" para usarlos desde cualquier carpeta de
    Windows, apuntando directamente al repositorio que acabas de clonar.

.DESCRIPTION
    Pensado para correrse justo después de "git clone" de este repositorio.

    Por defecto (sin -Copy):
    - NO copia los scripts a ninguna otra carpeta.
    - Registra en tu perfil de PowerShell ($PROFILE) las funciones "newpy", "syncpy" y
      "checkpy", apuntando a la ubicación exacta donde clonaste este repositorio (se detecta
      sola, con $PSScriptRoot).
    - Así, cuando actualices el repo con "git pull", los comandos usan la versión más
      reciente automáticamente, sin necesidad de reinstalar nada.
    - Importante: si mueves o borras la carpeta del repo clonado, los comandos dejan de
      funcionar. Si la mueves, vuelve a correr este instalador desde la nueva ubicación.

    Con -Copy:
    - Copia los scripts a una carpeta fija en tu perfil de usuario (por defecto
      $env:USERPROFILE\Scripts) y los comandos apuntan a esa copia en lugar del repo.
      Útil si prefieres poder borrar la carpeta clonada después de instalar.

    El instalador es idempotente y auto-reparable: si vuelves a correrlo (por ejemplo tras
    mover el repo, o cambiar entre modo copia / modo directo), reemplaza el bloque de
    funciones anterior en tu perfil en vez de duplicarlo.

.PARAMETER Copy
    Si se especifica, copia los scripts a -InstallDir en vez de apuntar directamente al
    repositorio clonado.

.PARAMETER InstallDir
    Solo aplica junto con -Copy. Carpeta donde copiar los scripts.
    Por defecto: $env:USERPROFILE\Scripts (Windows resuelve esta ruta automáticamente
    para el usuario que esté corriendo la terminal; no hay que reemplazar nada a mano).

.EXAMPLE
    .\Install-NewPyProject.ps1

.EXAMPLE
    .\Install-NewPyProject.ps1 -Copy

.EXAMPLE
    .\Install-NewPyProject.ps1 -Copy -InstallDir "D:\MisScripts"

.NOTES
    Ver documentación completa en DOCUMENTACION-New-PyProject.md
#>

param(
    [switch]$Copy,
    [string]$InstallDir = (Join-Path $env:USERPROFILE "Scripts")
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host ">> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "AVISO: $msg" -ForegroundColor Yellow }

# Carpeta donde vive este instalador = raíz del repo clonado
$repoRoot = $PSScriptRoot
$newProjectSrc = Join-Path $repoRoot "New-PyProject.ps1"
$syncReqSrc    = Join-Path $repoRoot "Sync-PyRequirements.ps1"
$checkSrc      = Join-Path $repoRoot "Test-PyProjectSetup.ps1"

if (-not (Test-Path $newProjectSrc)) {
    Write-Error "No se encontró New-PyProject.ps1 en '$repoRoot'. Corre este instalador desde la raíz del repositorio clonado."
    exit 1
}

# Rutas finales que usarán las funciones (dependen de si se copia o no)
if ($Copy) {
    if (-not (Test-Path $InstallDir)) {
        Write-Step "Creando carpeta de scripts en $InstallDir"
        New-Item -ItemType Directory -Path $InstallDir | Out-Null
        Write-Ok "Carpeta creada"
    } else {
        Write-Warn2 "La carpeta '$InstallDir' ya existe, se usará."
    }

    Write-Step "Copiando scripts a $InstallDir"
    Copy-Item -Path $newProjectSrc -Destination $InstallDir -Force
    $newProjectFinal = Join-Path $InstallDir "New-PyProject.ps1"

    $syncReqFinal = $null
    if (Test-Path $syncReqSrc) {
        Copy-Item -Path $syncReqSrc -Destination $InstallDir -Force
        $syncReqFinal = Join-Path $InstallDir "Sync-PyRequirements.ps1"
    }

    $checkFinal = $null
    if (Test-Path $checkSrc) {
        Copy-Item -Path $checkSrc -Destination $InstallDir -Force
        $checkFinal = Join-Path $InstallDir "Test-PyProjectSetup.ps1"
    }
    Write-Ok "Scripts copiados"
} else {
    Write-Step "Modo directo: los comandos apuntarán al repo clonado en $repoRoot"
    $newProjectFinal = $newProjectSrc
    $syncReqFinal = if (Test-Path $syncReqSrc) { $syncReqSrc } else { $null }
    $checkFinal = if (Test-Path $checkSrc) { $checkSrc } else { $null }
}

if (-not $syncReqFinal) {
    Write-Warn2 "No se encontró Sync-PyRequirements.ps1 junto al instalador. Se omite el comando 'syncpy'."
}
if (-not $checkFinal) {
    Write-Warn2 "No se encontró Test-PyProjectSetup.ps1 junto al instalador. Se omite el comando 'checkpy'."
}

# Preparar el perfil de PowerShell
if (-not (Test-Path $PROFILE)) {
    Write-Step "Creando archivo de perfil de PowerShell ($PROFILE)"
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Write-Ok "Perfil creado"
}

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if (-not $profileContent) { $profileContent = "" }

# Quitar cualquier bloque anterior (para reinstalar limpio, sin duplicar ni dejar rutas viejas)
$blockPattern = "(?s)\r?\n?# --- Inicio bloque New-PyProject \(agregado automáticamente\) ---.*?# --- Fin bloque New-PyProject ---\r?\n?"
$profileContent = [regex]::Replace($profileContent, $blockPattern, "")

$syncFunctionText = ""
if ($syncReqFinal) {
    $syncFunctionText = @"

function syncpy {
    param([string]`$Path = (Get-Location).Path)
    & "$syncReqFinal" -Path `$Path
}
"@
}

$checkFunctionText = ""
if ($checkFinal) {
    $checkFunctionText = @"

function checkpy {
    param([string]`$Path = (Get-Location).Path)
    & "$checkFinal" -Path `$Path
}
"@
}

$functionBlock = @"

# --- Inicio bloque New-PyProject (agregado automáticamente) ---
function newpy {
    param(
        [Parameter(Mandatory = `$true)][string]`$Name,
        [string]`$Path = (Get-Location).Path,
        [switch]`$NoGit,
        [switch]`$NoVSCode
    )
    & "$newProjectFinal" -Name `$Name -Path `$Path -NoGit:`$NoGit -NoVSCode:`$NoVSCode
}
$syncFunctionText
$checkFunctionText
# --- Fin bloque New-PyProject ---
"@

Write-Step "Escribiendo funciones en tu perfil de PowerShell"
Set-Content -Path $PROFILE -Value ($profileContent.TrimEnd() + "`r`n" + $functionBlock)
Write-Ok "Perfil actualizado"

# Revisar / ajustar la política de ejecución para el usuario actual
Write-Step "Revisando la política de ejecución de scripts"
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "Undefined") {
    try {
        Write-Step "Ajustando la política de ejecución (CurrentUser) a RemoteSigned"
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        Write-Ok "Política de ejecución actualizada"
    } catch {
        Write-Warn2 "No se pudo cambiar la política de ejecución automáticamente. Ejecuta manualmente: Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
    }
} else {
    Write-Ok "La política de ejecución actual ('$currentPolicy') ya permite ejecutar scripts locales"
}

Write-Host ""
Write-Ok "Instalación completa."
Write-Host "Cierra y vuelve a abrir la terminal (o ejecuta: . `$PROFILE) para poder usar los comandos desde cualquier carpeta." -ForegroundColor Magenta
Write-Host "Uso: newpy -Name mi-proyecto" -ForegroundColor Magenta
if ($syncReqFinal) {
    Write-Host "Uso: syncpy   (corre esto dentro de la carpeta de un proyecto ya creado)" -ForegroundColor Magenta
}
if ($checkFinal) {
    Write-Host "Uso: checkpy  (diagnostica el entorno y, si aplica, el proyecto en la carpeta actual)" -ForegroundColor Magenta
}

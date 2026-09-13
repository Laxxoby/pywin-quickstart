<#
.SYNOPSIS
    Crea rápidamente un proyecto de Python con entorno virtual, .gitignore y requirements.txt listo para pipreqs.

.DESCRIPTION
    New-PyProject.ps1 automatiza la creación de la estructura base de un proyecto Python:
    - Carpeta del proyecto
    - Entorno virtual (venv)
    - Archivo .gitignore preconfigurado
    - Instalación de pipreqs dentro del venv (para generar requirements.txt más adelante
      según los imports reales que uses en tu código, no todo lo instalado)
    - (Opcional) Inicialización de git
    - (Opcional) Apertura automática en VSCode

    El script es idempotente: si algo ya existe (carpeta, venv, .gitignore), no lo sobrescribe,
    solo avisa y continúa.

.PARAMETER Name
    Nombre del proyecto / carpeta a crear. Obligatorio.

.PARAMETER Path
    Ruta donde se creará la carpeta del proyecto. Por defecto, el directorio actual desde
    donde se ejecuta el comando.

.PARAMETER NoGit
    Si se especifica, no se inicializa un repositorio git.

.PARAMETER NoVSCode
    Si se especifica, no se abre VSCode automáticamente al finalizar.

.EXAMPLE
    New-PyProject.ps1 -Name mi-proyecto

.EXAMPLE
    New-PyProject.ps1 -Name mi-proyecto -Path "D:\Proyectos" -NoGit

.NOTES
    Ver documentación completa en DOCUMENTACION-New-PyProject.md
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [string]$Path = (Get-Location).Path,

    [switch]$NoGit,

    [switch]$NoVSCode
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host ">> $msg" -ForegroundColor Cyan
}

function Write-Ok($msg) {
    Write-Host "OK: $msg" -ForegroundColor Green
}

function Write-Warn2($msg) {
    Write-Host "AVISO: $msg" -ForegroundColor Yellow
}

# 1. Validar / crear carpeta del proyecto
$projectPath = Join-Path -Path $Path -ChildPath $Name

if (Test-Path $projectPath) {
    Write-Warn2 "La carpeta '$projectPath' ya existe. Se usará tal como está (no se sobrescribe contenido)."
} else {
    Write-Step "Creando carpeta del proyecto en $projectPath"
    New-Item -ItemType Directory -Path $projectPath | Out-Null
    Write-Ok "Carpeta creada"
}

Set-Location $projectPath

# 2. Verificar que Python esté disponible
Write-Step "Verificando Python"
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    Write-Error "No se encontró 'python' en el PATH. Instala Python y agrégalo al PATH antes de continuar."
    exit 1
}
Write-Ok "Python encontrado: $($pythonCmd.Source)"

# 3. Crear entorno virtual
$venvPath = Join-Path $projectPath "venv"
if (Test-Path $venvPath) {
    Write-Warn2 "Ya existe una carpeta 'venv'. Se omite la creación."
} else {
    Write-Step "Creando entorno virtual (venv)"
    python -m venv venv
    Write-Ok "Entorno virtual creado"
}

# 4. Crear .gitignore
$gitignorePath = Join-Path $projectPath ".gitignore"
if (Test-Path $gitignorePath) {
    Write-Warn2 "Ya existe un .gitignore. No se sobrescribe."
} else {
    Write-Step "Creando .gitignore"
    @"
.venv/
venv/
__pycache__/
*.pyc
.env
.env.*
"@ | Out-File -Encoding utf8 $gitignorePath
    Write-Ok ".gitignore creado"
}

# 5. Instalar pipreqs dentro del venv (queda listo para usarse más adelante)
Write-Step "Instalando pipreqs dentro del entorno virtual"
$venvPip = Join-Path $venvPath "Scripts\pip.exe"
if (Test-Path $venvPip) {
    & $venvPip install pipreqs --quiet
    Write-Ok "pipreqs instalado en el venv"
} else {
    Write-Warn2 "No se encontró pip dentro del venv, instala pipreqs manualmente más adelante."
}

# 6. Crear un requirements.txt vacío inicial (se llenará luego con pipreqs)
$reqPath = Join-Path $projectPath "requirements.txt"
if (-not (Test-Path $reqPath)) {
    New-Item -ItemType File -Path $reqPath | Out-Null
    Write-Ok "requirements.txt vacío creado (se llenará con 'pipreqs . --force' cuando tengas código)"
} else {
    Write-Warn2 "Ya existe un requirements.txt. No se sobrescribe."
}

# 7. Inicializar git (opcional)
if (-not $NoGit) {
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        Write-Step "Inicializando repositorio git"
        git init | Out-Null
        Write-Ok "Repositorio git inicializado"
    } else {
        Write-Warn2 "Git no está instalado o no está en el PATH. Se omite git init."
    }
}

# 8. Abrir en VSCode (opcional)
if (-not $NoVSCode) {
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    if ($codeCmd) {
        Write-Step "Abriendo el proyecto en VSCode"
        code .
    } else {
        Write-Warn2 "El comando 'code' no está disponible en el PATH. Abre VSCode manualmente."
    }
}

Write-Host ""
Write-Ok "Proyecto '$Name' listo en: $projectPath"
Write-Host "Recuerda activar el entorno virtual con: venv\Scripts\Activate.ps1" -ForegroundColor Magenta
Write-Host "Cuando tengas código con imports, genera tu requirements.txt real con: pipreqs . --force" -ForegroundColor Magenta

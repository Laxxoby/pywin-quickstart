<#
.SYNOPSIS
    Revisa de un vistazo si el entorno (Python, git, VSCode, PowerShell) y, si aplica, el
    proyecto en la carpeta actual, están listos para usar newpy / syncpy.

.DESCRIPTION
    Test-PyProjectSetup.ps1 agrupa en un solo comando los chequeos que normalmente hay que
    hacer a mano cuando algo falla: qué versión de Python se detecta, si git y VSCode están
    en el PATH, cuál es la política de ejecución de scripts, si las funciones newpy/syncpy
    ya quedaron registradas en el perfil de PowerShell, y (si se corre dentro de un proyecto)
    si el entorno virtual, pipreqs y requirements.txt están en buen estado.

    No modifica nada: solo informa. Es seguro correrlo en cualquier momento.

.PARAMETER Path
    Carpeta del proyecto a revisar (busca ahí '.venv' o 'venv'). Por defecto, la carpeta actual.
    Si la carpeta no es un proyecto (no tiene ninguna de las dos), simplemente se omiten esos
    chequeos y se informa el resto igual.

.EXAMPLE
    Test-PyProjectSetup.ps1

.EXAMPLE
    Test-PyProjectSetup.ps1 -Path "D:\Proyectos\mi-proyecto"

.NOTES
    Ver documentación completa en DOCUMENTACION-New-PyProject.md
#>

param(
    [string]$Path = (Get-Location).Path
)

function Write-Step($msg) { Write-Host ">> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "AVISO: $msg" -ForegroundColor Yellow }
function Write-Bad($msg)  { Write-Host "FALTA: $msg" -ForegroundColor Red }

Write-Host "=== Diagnóstico del entorno ===" -ForegroundColor Magenta

# 1. Python / py launcher
Write-Step "Python"
$pyLauncher = Get-Command py -ErrorAction SilentlyContinue
if ($pyLauncher) {
    $ver = (& py -3 --version) 2>&1
    Write-Ok "'py launcher' disponible. Versión más reciente detectada: $ver"
} else {
    Write-Warn2 "'py launcher' no está en el PATH (no es obligatorio, pero ayuda a elegir la versión más reciente)."
}
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if ($pythonCmd) {
    $ver = (& python --version) 2>&1
    Write-Ok "'python' disponible en: $($pythonCmd.Source) ($ver)"
} else {
    if (-not $pyLauncher) {
        Write-Bad "Ni 'python' ni 'py' están en el PATH. newpy no podrá crear entornos virtuales."
    } else {
        Write-Warn2 "'python' no está en el PATH, pero 'py' sí, así que newpy funcionará igual."
    }
}

# 2. Git
Write-Step "Git"
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    $ver = (& git --version) 2>&1
    Write-Ok "Disponible: $ver"
} else {
    Write-Warn2 "Git no está en el PATH. newpy seguirá funcionando, pero se omitirá 'git init' salvo que lo instales."
}

# 3. VSCode
Write-Step "VSCode (comando 'code')"
$codeCmd = Get-Command code -ErrorAction SilentlyContinue
if ($codeCmd) {
    Write-Ok "Disponible en: $($codeCmd.Source)"
} else {
    Write-Warn2 "'code' no está en el PATH. newpy no podrá abrir VSCode automáticamente (usa -NoVSCode para evitar el aviso)."
}

# 4. Política de ejecución
Write-Step "Política de ejecución de scripts (CurrentUser)"
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq "Restricted" -or $policy -eq "Undefined") {
    Write-Bad "Política actual: '$policy'. Los scripts .ps1 no van a poder correr. Ejecuta: Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
} else {
    Write-Ok "Política actual: '$policy' (permite ejecutar scripts locales)"
}

# 5. Perfil de PowerShell / comandos instalados
Write-Step "Comandos newpy / syncpy / checkpy en tu perfil"
if (Test-Path $PROFILE) {
    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    foreach ($fn in @("newpy", "syncpy", "checkpy")) {
        if ($profileContent -match "function\s+$fn\b") {
            Write-Ok "'$fn' está registrado en tu perfil"
        } else {
            Write-Warn2 "'$fn' NO está en tu perfil (corre Install-NewPyProject.ps1 si lo esperabas)"
        }
    }
} else {
    Write-Bad "No existe un archivo de perfil de PowerShell todavía ($PROFILE). Corre Install-NewPyProject.ps1."
}

# 6. Proyecto actual (si aplica)
Write-Host ""
Write-Host "=== Diagnóstico del proyecto en: $Path ===" -ForegroundColor Magenta

$dotVenvPath = Join-Path $Path ".venv"
$venvPath    = Join-Path $Path "venv"

if (Test-Path $dotVenvPath) {
    $activeVenvPath = $dotVenvPath
    Write-Ok "Entorno virtual encontrado: .venv"
} elseif (Test-Path $venvPath) {
    $activeVenvPath = $venvPath
    Write-Warn2 "Entorno virtual encontrado con el nombre antiguo: venv (sigue funcionando con syncpy)"
} else {
    $activeVenvPath = $null
    Write-Warn2 "No se encontró '.venv' ni 'venv' en esta carpeta. ¿Es esta la carpeta del proyecto? ¿Ya corriste newpy aquí?"
}

if ($activeVenvPath) {
    $venvPython = Join-Path $activeVenvPath "Scripts\python.exe"
    $venvPipreqs = Join-Path $activeVenvPath "Scripts\pipreqs.exe"

    if (Test-Path $venvPython) {
        $ver = (& $venvPython --version) 2>&1
        Write-Ok "Python del entorno virtual: $ver"
    } else {
        Write-Bad "No se encontró python.exe dentro del entorno virtual. Puede estar corrupto; considera borrarlo y volver a correr newpy."
    }

    if (Test-Path $venvPipreqs) {
        Write-Ok "pipreqs está instalado en el entorno virtual"
    } else {
        Write-Warn2 "pipreqs no está instalado en el entorno virtual (syncpy lo instalará solo la próxima vez que lo corras)"
    }
}

$gitignorePath = Join-Path $Path ".gitignore"
if (Test-Path $gitignorePath) {
    Write-Ok ".gitignore presente"
} else {
    Write-Warn2 ".gitignore no encontrado en esta carpeta"
}

$reqPath = Join-Path $Path "requirements.txt"
if (Test-Path $reqPath) {
    $reqContent = (Get-Content $reqPath -Raw).Trim()
    if ($reqContent.Length -gt 0) {
        $count = ($reqContent -split "`n" | Where-Object { $_.Trim().Length -gt 0 }).Count
        Write-Ok "requirements.txt presente, con $count línea(s)"
    } else {
        Write-Warn2 "requirements.txt existe pero está vacío (corre syncpy después de escribir imports)"
    }
} else {
    Write-Warn2 "requirements.txt no encontrado en esta carpeta"
}

$gitDirPath = Join-Path $Path ".git"
if (Test-Path $gitDirPath) {
    Write-Ok "Repositorio git inicializado"
} else {
    Write-Warn2 "No hay un repositorio git inicializado aquí"
}

Write-Host ""
Write-Host "=== Fin del diagnóstico ===" -ForegroundColor Magenta

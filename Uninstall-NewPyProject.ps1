<#
.SYNOPSIS
    Quita los comandos newpy / syncpy / checkpy de tu perfil de PowerShell.

.DESCRIPTION
    Uninstall-NewPyProject.ps1 revierte lo que hace Install-NewPyProject.ps1:
    - Busca en tu perfil de PowerShell ($PROFILE) el bloque de funciones agregado
      automáticamente (delimitado por los marcadores "# --- Inicio bloque New-PyProject ---"
      y "# --- Fin bloque New-PyProject ---") y lo elimina.
    - Si en su momento instalaste con -Copy (los scripts copiados a una carpeta aparte, por
      defecto $env:USERPROFILE\Scripts), puedes pedirle también que borre esa copia con
      -RemoveCopy.

    No toca los proyectos que ya creaste (carpetas con .venv, venv, .gitignore, etc.) ni el
    repositorio clonado: solo deshace el registro de los comandos.

.PARAMETER RemoveCopy
    Si se especifica, además borra los scripts copiados en -InstallDir (solo aplica si en su
    momento instalaste con -Copy).

.PARAMETER InstallDir
    Solo aplica junto con -RemoveCopy. Carpeta donde se habían copiado los scripts.
    Por defecto: $env:USERPROFILE\Scripts

.PARAMETER Force
    Si se especifica, borra los archivos de -RemoveCopy sin pedir confirmación.

.EXAMPLE
    .\Uninstall-NewPyProject.ps1

.EXAMPLE
    .\Uninstall-NewPyProject.ps1 -RemoveCopy

.NOTES
    Ver documentación completa en DOCUMENTACION-New-PyProject.md
#>

param(
    [switch]$RemoveCopy,
    [string]$InstallDir = (Join-Path $env:USERPROFILE "Scripts"),
    [switch]$Force
)

function Write-Step($msg) { Write-Host ">> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "AVISO: $msg" -ForegroundColor Yellow }

# 1. Quitar el bloque de funciones del perfil
if (-not (Test-Path $PROFILE)) {
    Write-Warn2 "No existe un archivo de perfil de PowerShell ($PROFILE). No hay nada que desinstalar ahí."
} else {
    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if (-not $profileContent) { $profileContent = "" }

    $blockPattern = "(?s)\r?\n?# --- Inicio bloque New-PyProject \(agregado automáticamente\) ---.*?# --- Fin bloque New-PyProject ---\r?\n?"
    if ($profileContent -match $blockPattern) {
        Write-Step "Quitando el bloque de funciones de tu perfil ($PROFILE)"
        $newContent = [regex]::Replace($profileContent, $blockPattern, "")
        Set-Content -Path $PROFILE -Value $newContent.TrimEnd()
        Write-Ok "Bloque eliminado. newpy / syncpy / checkpy dejarán de existir en nuevas terminales."
    } else {
        Write-Warn2 "No se encontró el bloque de New-PyProject en tu perfil (puede que ya lo hubieras quitado, o que nunca se haya instalado ahí)."
    }
}

# 2. Borrar la copia en InstallDir (opcional)
if ($RemoveCopy) {
    if (Test-Path $InstallDir) {
        $filesToRemove = @("New-PyProject.ps1", "Sync-PyRequirements.ps1", "Test-PyProjectSetup.ps1") |
            ForEach-Object { Join-Path $InstallDir $_ } |
            Where-Object { Test-Path $_ }

        if ($filesToRemove.Count -eq 0) {
            Write-Warn2 "No se encontraron scripts de New-PyProject en '$InstallDir'."
        } else {
            Write-Host "Se van a borrar estos archivos:" -ForegroundColor Yellow
            $filesToRemove | ForEach-Object { Write-Host "  - $_" }

            $proceed = $Force
            if (-not $proceed) {
                $answer = Read-Host "¿Confirmas que quieres borrarlos? (s/n)"
                $proceed = ($answer -eq "s" -or $answer -eq "S")
            }

            if ($proceed) {
                $filesToRemove | ForEach-Object { Remove-Item $_ -Force }
                Write-Ok "Archivos borrados de '$InstallDir'"
            } else {
                Write-Warn2 "Cancelado: no se borró nada en '$InstallDir'."
            }
        }
    } else {
        Write-Warn2 "La carpeta '$InstallDir' no existe, no hay nada que borrar ahí."
    }
} else {
    Write-Host "Nota: si instalaste con -Copy y quieres borrar también esa copia de los scripts, vuelve a correr esto con -RemoveCopy." -ForegroundColor Magenta
}

Write-Host ""
Write-Ok "Desinstalación completa."
Write-Host "Cierra y vuelve a abrir la terminal (o ejecuta: . `$PROFILE) para que el cambio tome efecto." -ForegroundColor Magenta

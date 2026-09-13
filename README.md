# pywin-quickstart

Repositorio: https://github.com/Laxxoby/pywin-quickstart

Scripts de PowerShell para automatizar la creación y el mantenimiento de proyectos Python en
Windows: entorno virtual, `.gitignore`, y `requirements.txt` generado a partir de los imports
reales del código (con `pipreqs`).

## Contenido

| Archivo                       | Qué hace                                                                 |
|--------------------------------|---------------------------------------------------------------------------|
| `New-PyProject.ps1`            | Crea un proyecto nuevo: carpeta, `venv`, `.gitignore`, git init, VSCode.  |
| `Sync-PyRequirements.ps1`      | Dentro de un proyecto existente, detecta imports e instala lo que falte. |
| `Install-NewPyProject.ps1`     | Instala los comandos `newpy` y `syncpy`, disponibles desde cualquier carpeta de Windows. |
| `DOCUMENTACION-New-PyProject.md` | Documentación completa: qué hace cada script, changelog, y un prompt para pedirle a una IA que le agregue funciones nuevas. |

## Instalación (una sola vez)

```powershell
git clone https://github.com/Laxxoby/pywin-quickstart.git
cd pywin-quickstart
.\Install-NewPyProject.ps1
```

Cierra y vuelve a abrir la terminal (o corre `. $PROFILE`).

Por defecto, el instalador **no copia nada**: registra los comandos `newpy` y `syncpy` apuntando
directamente a esta carpeta clonada. Si más adelante actualizas el repo con `git pull`, los
comandos usan la versión más reciente automáticamente, sin reinstalar nada.

> Si prefieres tener una copia independiente de los scripts (por ejemplo, para poder borrar esta
> carpeta clonada después), usa `.\Install-NewPyProject.ps1 -Copy` en su lugar.

## Uso

```powershell
# Crear un proyecto nuevo, desde cualquier carpeta
newpy -Name mi-proyecto

# Dentro de un proyecto ya creado, después de escribir código con imports
syncpy
```

Ver `DOCUMENTACION-New-PyProject.md` para el detalle completo de cada script, sus parámetros,
y el historial de cambios.

## Actualizar

```powershell
git pull
```

Si instalaste en modo directo (sin `-Copy`), no necesitas hacer nada más. Si instalaste con
`-Copy`, vuelve a correr `.\Install-NewPyProject.ps1 -Copy` después de cada `git pull`.

# Documentación: `New-PyProject.ps1`, `Install-NewPyProject.ps1` y `Sync-PyRequirements.ps1`

Este documento describe qué hace actualmente cada script del proyecto, cómo instalarlos para
usarlos desde cualquier carpeta de Windows, y cómo retomar este proyecto con una IA en el futuro
sin perder contexto.

Son tres scripts complementarios:
- **`New-PyProject.ps1`**: crea la estructura inicial de un proyecto nuevo.
- **`Install-NewPyProject.ps1`**: instala `New-PyProject.ps1` como el comando `newpy`, disponible
  desde cualquier carpeta de Windows (automatiza lo que antes era la instalación manual).
- **`Sync-PyRequirements.ps1`**: se corre dentro de un proyecto ya existente cada vez que agregas
  código nuevo, para detectar imports e instalar automáticamente lo que falte.

---

## 1. ¿Qué es?

Un script de PowerShell que automatiza la creación de la estructura base de un proyecto Python:
entorno virtual, `.gitignore`, y preparación para generar `requirements.txt` a partir de los
imports reales del código (con `pipreqs`, no `pip freeze`).

Reemplaza el proceso manual de ir escribiendo comando por comando cada vez que se inicia un
proyecto nuevo.

---

## 2. Estado actual de `New-PyProject.ps1` (v1.4)

El script, al ejecutarse, hace lo siguiente en orden:

1. Crea la carpeta del proyecto en la ruta indicada (o usa la actual si ya existe, sin borrar contenido).
2. Busca la versión de Python más reciente instalada: si el "py launcher" de Windows (`py`) está
   disponible, usa `py -3` (que apunta automáticamente a la versión 3.x más nueva instalada); si
   no, cae de vuelta a `python`. Si ninguno está disponible, se detiene con un error claro.
   Muestra en pantalla qué versión exacta se va a usar.
3. Crea el entorno virtual en una carpeta **`.venv/`** (si no existe ya) con la versión de Python
   detectada en el paso anterior, y lo activa automáticamente en la sesión actual de PowerShell.
4. Crea el archivo `.gitignore` con este contenido exacto:
   ```
   .venv/
   venv/
   __pycache__/
   *.pyc
   .env
   .env.*
   ```
   (incluye ambos nombres, `.venv/` y `venv/`, por si en algún momento se usa el nombre antiguo).
5. Actualiza `pip` dentro del `.venv` recién creado (`pip install --upgrade pip`), y luego instala
   `pipreqs`, para que quede listo para usarse en cuanto haya código.
6. Crea un `requirements.txt` vacío como marcador inicial.
7. Inicializa un repositorio git (`git init`), salvo que se use el flag `-NoGit`.
8. Abre el proyecto en VSCode (`code .`), salvo que se use el flag `-NoVSCode`.

El script es **idempotente**: si algo ya existe (carpeta, `.venv`, `.gitignore`, `requirements.txt`),
no lo sobrescribe; solo muestra un aviso en amarillo y continúa con el resto.

Usa funciones auxiliares internas para los mensajes en consola:
- `Write-Step` (cian, "haciendo esto ahora")
- `Write-Ok` (verde, "esto terminó bien")
- `Write-Warn2` (amarillo, "aviso, algo ya existía o falta una herramienta")

### Parámetros

| Parámetro   | Tipo   | Obligatorio | Descripción                                                              |
|-------------|--------|-------------|---------------------------------------------------------------------------|
| `-Name`     | string | Sí          | Nombre del proyecto / carpeta a crear.                                    |
| `-Path`     | string | No          | Carpeta donde crear el proyecto. Por defecto, la carpeta actual.          |
| `-NoGit`    | switch | No          | Si se pasa, no ejecuta `git init`.                                        |
| `-NoVSCode` | switch | No          | Si se pasa, no abre VSCode automáticamente.                               |

---

## 2.1 Estado actual de `Sync-PyRequirements.ps1` (v1.4)

Este script automatiza el paso de "instalar las librerías que uso" (antes manual con
`pip install algo`). Se corre **dentro de un proyecto ya creado** (con un entorno virtual
existente), después de escribir o modificar código con `import`. Hace lo siguiente:

1. Busca el entorno virtual del proyecto: primero revisa si existe `.venv` (nombre actual, creado
   por `New-PyProject.ps1`); si no, revisa `venv` (nombre usado por versiones anteriores del
   script). Si no encuentra ninguna de las dos, se detiene con un error claro. Así, tanto los
   proyectos nuevos como los creados antes de este cambio siguen funcionando sin tocar nada.
2. Si `pipreqs` no está instalado en el entorno virtual detectado, lo instala primero.
3. Corre `pipreqs . --force` usando el `pipreqs` del venv del proyecto (sin necesidad de activar
   el venv en la terminal actual), y regenera `requirements.txt` con lo que detecta en el código.
   `pipreqs` no necesita que las librerías ya estén instaladas para detectarlas: solo lee los
   `import` del código y resuelve la versión más reciente contra PyPI.
4. Si `requirements.txt` quedó con contenido, instala todo eso en el venv con
   `pip install -r requirements.txt`. Si quedó vacío, solo avisa (amarillo) y no falla.

Con esto, el flujo pasa de "escribir import -> instalar a mano -> generar requirements" a
"escribir import -> correr un solo comando".

### Parámetros

| Parámetro | Tipo   | Obligatorio | Descripción                                                                 |
|-----------|--------|-------------|--------------------------------------------------------------------------------|
| `-Path`   | string | No          | Ruta del proyecto (donde está `.venv` o `venv`). Por defecto, la carpeta actual. |

---

## 3. Cómo guardarlo en GitHub y usarlo desde cualquier parte de Windows (clonar + instalar)

Ahora el flujo es: el proyecto vive en un repositorio de GitHub, se clona una vez en cualquier
máquina, y un instalador registra los comandos apuntando directamente a esa carpeta clonada
(sin copiar archivos a ningún otro lado por defecto).

### 3.1 Subir el proyecto a GitHub (ya hecho)

El repositorio ya existe en: **https://github.com/Laxxoby/pywin-quickstart**

Para referencia, así se subió la primera vez desde la carpeta local:
   ```powershell
   git init
   git add .
   git commit -m "Estructura inicial: New-PyProject, Sync-PyRequirements, Install-NewPyProject"
   git branch -M main
   git remote add origin https://github.com/Laxxoby/pywin-quickstart.git
   git push -u origin main
   ```

### 3.2 Clonarlo e instalarlo en cualquier equipo (o de nuevo en el mismo)

```powershell
git clone https://github.com/Laxxoby/pywin-quickstart.git
cd pywin-quickstart
.\Install-NewPyProject.ps1
```

Cierra y abre de nuevo la terminal (o ejecuta `. $PROFILE`).

### Qué hace `Install-NewPyProject.ps1` ahora

- **Modo por defecto (sin `-Copy`)**: no copia nada. Registra en tu perfil de PowerShell
  (`$PROFILE`) las funciones `newpy` y `syncpy` apuntando directamente a la carpeta donde
  clonaste el repo (`$PSScriptRoot`, se detecta solo). Si luego actualizas con `git pull`,
  los comandos usan la versión más reciente sin reinstalar nada.
- **Modo `-Copy`**: copia los scripts a una carpeta fija (por defecto
  `$env:USERPROFILE\Scripts`) y los comandos apuntan a esa copia en vez del repo. Útil si
  quieres poder borrar la carpeta clonada después.
- En ambos modos, revisa la política de ejecución de scripts y la ajusta si es demasiado
  restrictiva.
- Es **auto-reparable**: si vuelves a correrlo (por ejemplo tras mover el repo, o cambiar de
  modo directo a `-Copy`), reemplaza el bloque de funciones anterior en tu perfil en vez de
  duplicarlo o dejar rutas viejas apuntando a ningún lado.

### Sobre `<usuario>` y las rutas: ya está automatizado

No hace falta reemplazar manualmente ningún nombre de usuario en ningún archivo. El script usa
`$env:USERPROFILE`, una variable que Windows resuelve solo para el usuario que esté corriendo la
terminal (por ejemplo `C:\Users\Juan` o `C:\Users\Maria`), incluso si el perfil está en una unidad
distinta o redirigido por políticas corporativas — es más confiable que construir la ruta a mano
con `C:\Users\$env:USERNAME`. Y en el modo por defecto (sin `-Copy`) ni siquiera se usa esa
variable, porque no se copia nada a la carpeta de usuario: todo apunta directamente al repo
clonado, sea cual sea su ubicación.

### Uso diario, desde cualquier carpeta

```powershell
newpy -Name mi-proyecto
newpy -Name otro-proyecto -Path "D:\Proyectos" -NoGit
syncpy
```

### Actualizar

```powershell
git pull
```

Si instalaste en modo directo, no hace falta nada más. Si instalaste con `-Copy`, vuelve a correr
`.\Install-NewPyProject.ps1 -Copy` después de cada `git pull`.

---

## 4. Estructura que queda generada

```
mi-proyecto/
├── .venv/
├── .gitignore
└── requirements.txt   (vacío al inicio)
```

## 5. Flujo de trabajo recomendado después de crear el proyecto

1. El entorno virtual ya queda activado automáticamente al terminar `newpy` (verás `(.venv)` en
   el prompt). Si necesitas activarlo de nuevo más tarde (otra terminal, VSCode, etc.):
   `.venv\Scripts\Activate.ps1`
2. Escribir tu código y sus `import`.
3. Correr `syncpy` (o `Sync-PyRequirements.ps1`) para detectar los imports, actualizar
   `requirements.txt` e instalar automáticamente lo que falte — ya no hace falta `pip install`
   manual para cada librería nueva.
4. Confirmar cambios en git: `git add .` y `git commit -m "..."`

---

## 6. Historial de cambios (Changelog)

- **v1.0** (2026-09-13): Versión inicial. Crea carpeta, venv, `.gitignore`, instala `pipreqs`,
  crea `requirements.txt` vacío, `git init` opcional, apertura en VSCode opcional. Script idempotente.
- **v1.2** (2026-09-13): Se agrega `Install-NewPyProject.ps1`, que automatiza el paso de dejar
  `newpy` disponible desde cualquier carpeta de Windows: crea la carpeta de scripts, copia/actualiza
  `New-PyProject.ps1`, agrega la función `newpy` al perfil de PowerShell sin duplicarla si ya existe,
  y ajusta la política de ejecución si es demasiado restrictiva. Reemplaza los pasos manuales que
  antes estaban en la sección 3 de este documento.
- **v1.3** (2026-09-13): El proyecto pasa a vivir en un repositorio de GitHub (se agrega `README.md`
  con instrucciones de clonado). `Install-NewPyProject.ps1` cambia su comportamiento por defecto:
  ya no copia archivos a `C:\Users\<usuario>\Scripts`, sino que registra `newpy` y `syncpy`
  apuntando directamente a la carpeta del repo clonado (detectada sola con `$PSScriptRoot`), para
  que `git pull` actualice los comandos sin reinstalar. El comportamiento anterior (copiar a una
  carpeta fija) queda disponible con el switch `-Copy`, usando `$env:USERPROFILE` en vez de
  construir la ruta con `$env:USERNAME`. El instalador ahora también reemplaza limpiamente su
  propio bloque en el perfil en cada corrida (en vez de solo detectar duplicados), para que
  funcione bien si el repo se mueve o se reinstala en otro modo.
- **v1.4** (2026-09-13): Tres cambios en `New-PyProject.ps1` y `Sync-PyRequirements.ps1`:
  1. `New-PyProject.ps1` ahora detecta la versión de Python más reciente instalada (usa el
     "py launcher" de Windows con `py -3` si está disponible, en vez de asumir que `python`
     apunta a la versión correcta) y muestra en pantalla cuál va a usar.
  2. Antes de instalar `pipreqs`, el script actualiza `pip` dentro del entorno virtual
     (`pip install --upgrade pip`), para evitar avisos de versión desactualizada.
  3. El entorno virtual ahora se crea en una carpeta `.venv/` en vez de `venv/` (el `.gitignore`
     ya cubría ambos nombres desde el inicio). `Sync-PyRequirements.ps1` se actualizó para
     detectar automáticamente cuál de las dos carpetas existe (`.venv` primero, `venv` como
     respaldo), de forma que los proyectos creados con versiones anteriores del script sigan
     funcionando sin cambios.

> Cada vez que se agregue una función nueva al script, se debe sumar una entrada aquí con la
> versión, la fecha y qué cambió, para no perder el rastro de la evolución del proyecto.

---

## 7. Prompt para retomar este proyecto con una IA en el futuro

Si en el futuro quieres pedirle a una IA (Claude u otra) que le agregue funciones nuevas a este
proyecto, adjúntale **este archivo `.md`** junto con los scripts actuales (`New-PyProject.ps1`,
`Install-NewPyProject.ps1` y `Sync-PyRequirements.ps1`), y usa un mensaje como este:

```
Vas a modificar los scripts de PowerShell "New-PyProject.ps1", "Install-NewPyProject.ps1" y
"Sync-PyRequirements.ps1", que juntos automatizan crear proyectos Python (venv, .gitignore,
pipreqs, git init opcional, apertura en VSCode), instalar el comando "newpy" en cualquier
carpeta de Windows, y mantener requirements.txt sincronizado con los imports del código.

Te adjunto el código actual de los scripts y su documentación (DOCUMENTACION-New-PyProject.md),
que describe todas las funciones existentes, los parámetros, y las convenciones usadas
(funciones auxiliares Write-Step / Write-Ok / Write-Warn2, chequeos de idempotencia antes de
crear cualquier archivo o carpeta, parámetros con switches -NoAlgo, etc).

Cuando implementes algo nuevo:
1. Sigue las mismas convenciones de estilo y las funciones auxiliares ya existentes en el script.
2. No rompas ni elimines funcionalidad existente salvo que te lo pida explícitamente.
3. Mantén el comportamiento idempotente (si algo ya existe, avisar y no sobrescribir, salvo que
   se indique lo contrario).
4. Actualiza la sección "Estado actual" del .md agregando la nueva función.
5. Si agregas parámetros nuevos, actualiza la tabla de parámetros del .md.
6. Agrega una entrada nueva en la sección "Historial de cambios" del .md: versión incremental
   (ej. v1.1), fecha, y una descripción breve de qué se añadió y por qué.
7. Devuélveme el script completo actualizado y el .md completo actualizado (no fragmentos
   sueltos), para reemplazar los archivos directamente.

Esto es lo que quiero que agregues ahora: [DESCRIBE AQUÍ LA NUEVA FUNCIÓN QUE QUIERES]
```

Esto asegura que cualquier IA que retome el proyecto entienda de inmediato qué existe, cómo está
construido, y deje registro de lo que cambia, para que el historial no se pierda.

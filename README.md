# pacwin

Capa de abstracción sobre los gestores de paquetes de Windows.  
No instala nada propio — coordina **winget**, **chocolatey** y **scoop**.

Compatible con PowerShell 5.1 y PowerShell 7+.

## Instalación

```powershell
# Desde el directorio del repo (como admin si usas choco):
.\install.ps1
```

Copia el módulo a `~/Documents/WindowsPowerShell/Modules/pacwin` (PS5.1) o  
`~/Documents/PowerShell/Modules/pacwin` (PS7) y agrega el `Import-Module` al perfil.

## Comandos

| Comando | Descripción |
|---|---|
| `pacwin search <nombre>` | Busca en todos los gestores activos en paralelo |
| `pacwin install <nombre>` | Busca, muestra tabla numerada, instalas lo que eliges |
| `pacwin uninstall <nombre>` | Desinstala (elige gestor interactivamente o con -Manager) |
| `pacwin update [nombre]` | Actualiza todo o un paquete específico |
| `pacwin upgrade [nombre]` | Alias de update |
| `pacwin outdated` | Lista paquetes con actualizaciones disponibles |
| `pacwin list [filtro]` | Lista instalados por gestor |
| `pacwin info <nombre>` | Info detallada del paquete |
| `pacwin status` | Gestores disponibles + rutas de ejecutables |

## Flags

```powershell
-Manager  winget|choco|scoop    # Restringe la operación a un gestor
-Limit    N                     # Máximo de resultados en search/install (default: 40)
```

## Ejemplos

```powershell
pacwin search vlc
pacwin install nodejs
pacwin install nodejs -Manager scoop
pacwin search ffmpeg -Limit 10
pacwin update
pacwin update vlc -Manager choco
pacwin outdated
pacwin list reaper
pacwin uninstall 7zip -Manager winget
pacwin status
```

## Flujo de install

1. Busca en todos los gestores activos (paralelo, timeout 25s por gestor)
2. Muestra resultados numerados — prioriza coincidencias exactas
3. Eliges el número
4. Si el mismo ID existe en múltiples fuentes, aparece un segundo selector de fuente
5. Delega al gestor nativo correspondiente

## Colores en pantalla

- **Cyan** → winget  
- **Amarillo** → chocolatey  
- **Verde** → scoop

## Notas técnicas

- Los jobs de búsqueda paralela reciben la ruta absoluta del ejecutable  
  para no depender del PATH heredado (workaround para PS5.1 en Windows)
- El parser de winget usa offsets de columna exactos cuando detecta el header,  
  con fallback a split por espacios múltiples
- `choco list --local-only` fue reemplazado por `choco list` (deprecado en choco v2)

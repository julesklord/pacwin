# pacwin

Capa de abstracción sobre los gestores de paquetes de Windows.
No instala nada propio — coordina **winget**, **chocolatey** y **scoop**.

## Instalación

```powershell
# Desde el directorio del repo:
.\install.ps1
```

Esto copia el módulo a `~/Documents/PowerShell/Modules/pacwin` y agrega
`Import-Module pacwin` a tu perfil.

## Comandos

| Comando | Descripción |
|---|---|
| `pacwin search <nombre>` | Busca en todos los gestores activos (paralelo) |
| `pacwin install <nombre>` | Busca, muestra resultados, instala el elegido |
| `pacwin uninstall <nombre>` | Desinstala (elige gestor interactivamente) |
| `pacwin update [nombre]` | Actualiza todo o un paquete específico |
| `pacwin list [filtro]` | Lista instalados (por gestor) |
| `pacwin info <nombre>` | Info detallada del paquete |
| `pacwin status` | Muestra qué gestores están disponibles |

## Flags

```powershell
-Manager winget|choco|scoop    # Fuerza un gestor específico
```

## Ejemplos

```powershell
pacwin search vlc
pacwin install nodejs
pacwin install nodejs -Manager scoop
pacwin update
pacwin update vlc -Manager choco
pacwin list reaper
pacwin uninstall 7zip
```

## Flujo de install

1. Busca en todos los gestores activos
2. Muestra resultados numerados con versión y fuente (color por gestor)
3. Pides el número
4. Si el mismo paquete existe en múltiples fuentes, pide que elijas
5. Instala con el gestor correspondiente

## Colores

- **Cyan** → winget  
- **Amarillo** → chocolatey  
- **Verde** → scoop

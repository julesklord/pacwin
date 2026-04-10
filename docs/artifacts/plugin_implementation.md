# PoshBuddy — Sistema de Gestión de Plugins (PowerShell Modules)

Se ha completado la Fase 14, integrando el soporte para extensiones y módulos de PowerShell directamente en la TUI.

## Cambios Realizados

### 🔌 Gestión de Plugins (PowerShell Modules)
- **Infraestructura Core**: Añadida la estructura `PluginAsset` y el estado `ActiveView::Plugins` en `app.rs`.
- **Lista Curada**: Se incluyeron por defecto 4 plugins esenciales:
  - `Terminal-Icons`: Iconos para archivos y carpetas.
  - `posh-git`: Estado detallado de Git.
  - `zoxide`: Navegación inteligente de directorios.
  - `PSReadLine Mastery`: Predicciones estilo Fish y resaltado sintáctico.

### ⚙️ Automatización de Perfiles
- **Activación Inteligente**: Al presionar `ENTER` en un plugin, PoshBuddy detecta si ya está activo y lo añade o elimina automáticamente de todos tus perfiles de PowerShell detectados (`Import-Module` o scripts de init).
- **Detección de Estado**: La UI muestra dinámicamente si un módulo está `[X] ACTIVE` o `[ ] INACTIVE`.

### 🖥️ Interfaz de Usuario (UI)
- **Nueva Pestaña [3]**: Acceso directo al gestor de módulos.
- **Panel de Documentación**: Se muestra la descripción técnica y guías de uso de cada extensión en lugar del preview visual.
- **Navegación Fluida**: Ciclo de pestañas `Themes -> Fonts -> Plugins` mediante `TAB`.

### 🛠️ Estabilidad
- **Internacionalización**: Todo el código de la nueva fase incluye documentación inline en inglés.
- **Cero Errores sintácticos**: Corregida la lógica de navegación y handlers de eventos tras la integración.

## Estado de Git
```bash
# Sincronización final:
# (Pendiente commit) Integración de Plugins y Módulos PS
```

---
> [!IMPORTANT]
> El sistema de plugins ahora permite una personalización completa del terminal sin tocar una sola línea de código en el $PROFILE.

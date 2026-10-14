<div align="center">

<img src="../images/appicon.png" alt="LockIME" width="128">

# LockIME Voice

[English](../../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · **Español** · [Português](README.pt.md) · [Русский](README.ru.md)

[![CI](https://img.shields.io/github/actions/workflow/status/zhangsiqiang519/LockIME-Voice/ci.yml?branch=main&label=CI)](https://github.com/panda-z519/LockIME-Voice/actions/workflows/ci.yml)
[![Licencia: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-3A5BD9)](../../LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)

</div>

> **Fork de código fuente LockIME Voice.** Este derivado GPL-3.0 añade el flujo de entrada por voz configurable. `v0.1.5` ofrece instaladores preliminares con firma ad-hoc, pero no firma Developer ID, notarización, Sparkle ni Homebrew.

Una aplicación de barra de menús para macOS que **bloquea tu fuente de entrada de teclado**. Cada vez que tú (u otra aplicación) cambias el método de entrada, LockIME vuelve inmediatamente al bloqueado — globalmente, por aplicación en primer plano, o (con el modo mejorado opcional) por URL del navegador.

> macOS 14+ · Apple silicon e Intel — aplicaciones separadas, descarga el
> archivo `-arm64` o `-x86_64` que corresponda a tu Mac · construida con
> SwiftUI, Liquid Glass en macOS 26 (Tahoe).

## Screenshots

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-general-en-dark.png">
    <img alt="Ajustes generales" src="../images/settings-general-en-light.png" width="32%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-app-rules-en-dark.png">
    <img alt="Reglas por aplicación" src="../images/settings-app-rules-en-light.png" width="32%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-url-rules-en-dark.png">
    <img alt="Reglas por URL" src="../images/settings-url-rules-en-light.png" width="32%">
  </picture>
</p>

## Changes in LockIME Voice

Frente al proyecto upstream, este fork añade una fuente de voz configurable, un único atajo de voz que LockIME asume (consume la tecla, así que no hay conflicto), un cambio temporal de fuente de entrada durante la voz que es opcional y está desactivado por defecto, restauración del valor global de **App Rules**, sesiones repetibles con timeout y la fuente predeterminada primero con un icono de chincheta.

![Ajustes de entrada por voz de LockIME Voice](../images/settings-voice-input-zh-CN.png)

## Install

Descarga el instalador correspondiente:

- [Apple silicon (arm64)](https://github.com/panda-z519/LockIME-Voice/releases/download/v0.1.5/LockIME-Voice-0.1.5-arm64.dmg)
- [Intel (x86_64)](https://github.com/panda-z519/LockIME-Voice/releases/download/v0.1.5/LockIME-Voice-0.1.5-x86_64.dmg)

Verifica la descarga antes de abrirla. Cada release publica un `SHA256SUMS.txt`,
así que la suma de comprobación siempre coincide con el artefacto compilado para
ese tag (el DMG no es reproducible, por eso aquí no se fija ninguna):

```sh
gh release download v0.1.3 --repo panda-z519/LockIME-Voice \
  --pattern 'LockIME-Voice-0.1.5-*.dmg' --pattern SHA256SUMS.txt
shasum -a 256 -c SHA256SUMS.txt
```

Esa verificación es lo que hace seguro pulsar **Abrir igualmente** en una
compilación sin notarizar: nunca omitas Gatekeeper para una descarga sin comprobar.


Abre el DMG y arrastra **LockIME Voice** a Aplicaciones. Esta versión preliminar solo está firmada ad-hoc y **no está notarizada**, así que Gatekeeper bloquea el primer inicio:

1. Haz doble clic en **LockIME Voice**. macOS lo rechazará con *«Apple no ha podido verificar que LockIME Voice esté libre de malware»*: es lo esperado y no significa que la descarga esté dañada.
2. Abre **Ajustes del Sistema ▸ Privacidad y seguridad** y baja hasta la sección **Seguridad**. Ahí aparecerá **LockIME Voice** con el botón **Abrir igualmente**.
3. Pulsa **Abrir igualmente**, autentícate y confirma con **Abrir** en el diálogo siguiente. A partir de ahí la app arranca con normalidad.

Confía solo en una copia descargada desde la página de releases de este repositorio y cuyo SHA-256 coincida con la suma de comprobación de arriba: eso es lo que hace seguro pulsar «Abrir igualmente» en una compilación sin notarizar. Tras iniciarla, concede **Accesibilidad** cuando se solicite (el flujo de entrada de voz la necesita; ese mismo cuadro de diálogo también cubre el envío de eventos de teclado).

También puedes compilar desde el código:

```sh
brew install xcodegen xcbeautify
make build
open "build/DerivedData/Build/Products/Debug/LockIME Voice Dev.app"
```

Tras reinstalar o recompilar puede ser necesario volver a conceder permisos. No hay actualizaciones automáticas.

## Features

- **Rebloqueo instantáneo** — devuelve la fuente de entrada activa a la bloqueada en el momento en que tú (u otra aplicación) la cambias, globalmente o por aplicación.
- **Detección de conflictos** — si otro programa vuelve a imponer una y otra vez su propia fuente de entrada (por ejemplo, un juego con gestión de IME integrada), LockIME detecta el tira y afloja y se aparta brevemente en lugar de alternar sin fin, registrando *Conflicto detectado* en el registro de activaciones; dale a esa aplicación su propia regla *Ignorar* o *Cambiar a* para una solución duradera.
- **Reglas para procesos sin bundle** — los programas que se ejecutan desde un ejecutable suelto en lugar de un bundle `.app` (por ejemplo, el `java` de Minecraft, lanzado por un launcher de terceros) también pueden tener reglas: mientras están en ejecución, el selector de aplicaciones los muestra bajo una identidad sintética `process:<executable>` (por ejemplo, `process:java`).
- **Bloquear o cambiar** — las reglas por aplicación y por URL pueden *bloquear* una fuente de entrada (se vuelve a aplicar cada vez que se desvía) o solo *cambiar* a ella una vez cuando activas la aplicación o la página, y luego dejarte cambiarla libremente.
- **Bloquear de forma global, o solo cambiar** — asigna a la fuente de entrada predeterminada global uno de tres comportamientos: *bloquear* para fijarla en todas partes; *cambiar* para cambiarte a ella una vez cada vez que una aplicación recurre a la predeterminada global (no tiene regla propia, o su regla es *Usar predeterminada*) y luego dejarte libre; o **Ninguna** para no tener ningún comportamiento global en absoluto — entonces LockIME actúa solo a través de tus reglas por aplicación y por URL. *Cambiar* te cambia activamente cada vez que se aplica la predeterminada; **Ninguna** no hace nada de forma global.
- **Coincidencia de URL flexible** — las reglas por URL (modo mejorado) coinciden por un dominio y sus subdominios, por un dominio exacto, por una palabra clave de dominio o por una expresión regular sobre la URL completa, y se aplican en el orden de prioridad que tú arrastras para organizar — la primera coincidencia gana.
- **Control desde la barra de menús** — activa/desactiva, cambia la fuente de entrada bloqueada, consulta la fuente actual y sigue el contador de activaciones desde la barra de menús.
- **Atajos de teclado** — atajos globales configurables para activar/desactivar LockIME y recorrer la fuente de entrada bloqueada, además de atajos por aplicación para recorrer o eliminar la regla de la aplicación en primer plano.
- **Flujo de entrada por voz** — cambia temporalmente desde tu fuente de entrada diaria a una fuente configurada con voz, envía el atajo de voz propio de ese método de entrada y luego restaura tu fuente diaria. El comportamiento y el atajo configurados en LockIME deben coincidir con los ajustes de entrada por voz del método de entrada seleccionado.
- **Arranque al iniciar sesión** — se inicia automáticamente al iniciar sesión (desactivado por defecto).
- **Modo claro y oscuro** — un lenguaje de diseño unificado y nativo del sistema que se adapta a la apariencia clara y oscura, además de un icono de aplicación a medida. Ver [docs/DESIGN.md](../DESIGN.md).
- **Cambio de idioma en vivo** — cambia al instante entre 9 idiomas, sin reiniciar: English, 简体中文, 繁體中文, 日本語, Français, Deutsch, Español, Português, Русский.
- **Registro de activaciones de 24 horas** — revisa qué se cambió, por qué y durante cuánto tiempo.
- **Copia de seguridad de la configuración** — exporta tus reglas por aplicación y por URL a un archivo `.lockime` e impórtalas de vuelta, con un paso de previsualización que muestra las adiciones, los conflictos y las eliminaciones antes de aplicar nada.
- **Descarga diminuta** — toda la aplicación cabe en un `.dmg` de menos de 3 MB.
- **Sin permisos del sistema para el bloqueo básico** — un modo mejorado opcional, protegido por Accessibility, desbloquea reglas más finas por URL y por campo con el foco.
- **Automatización** — un esquema de URL `lockime-voice://` permite que otras aplicaciones, scripts y Shortcuts controlen LockIME (ver más abajo).

## Voice Input Workflow

La fuente de entrada por voz es totalmente configurable; LockIME Voice no fija Doubao, WeChat ni ningún otro método de entrada.

1. Abre **Settings ▸ Voice Input** y activa el flujo de trabajo.
2. Graba el **atajo de voz**: el mismo que usas para la entrada de voz dentro de tu método de entrada. LockIME asume esa tecla.
3. Opcional: elige una fuente de entrada por voz y activa el cambio automático.
4. Concede **Accesibilidad**. Es necesaria para que LockIME asuma el atajo de voz; sin ella la tecla llega al método de entrada y macOS vuelve a avisar de un conflicto de atajos. El bloqueo principal sigue sin necesitar permisos.

### Por qué ya no hay conflicto

LockIME consume la tecla de voz, así que tu método de entrada nunca ve la pulsación física: no hay nada con lo que chocar. Después LockIME envía esa misma tecla para iniciar y detener la grabación, marcada para que su propio monitor ignore el eco.

Esa es la diferencia con el diseño anterior de dos atajos, que te pedía mantener dos combinaciones distintas y aun así dejaba que el método de entrada reaccionara a su propia tecla.

Prueba el flujo en TextEdit u otro campo de texto simple. Ver el panel de voz no basta: el texto reconocido debe aparecer en la posición actual del cursor.
## Comparison

Las dos alternativas a LockIME más utilizadas son
**[Input Source Pro](https://github.com/runjuu/InputSourcePro)** y
**[KeyboardHolder](https://github.com/leaves615/KeyboardHolder)**, junto con una
larga cola de herramientas de código abierto y de CLI más pequeñas. Todas ellas
*cambian* la fuente de entrada a medida que te mueves entre aplicaciones o
sitios; LockIME está construida en torno a un **bloqueo** continuo que la vuelve
a aplicar en el momento en que se desvía — sin dejar de permitir que cualquier
regla recurra a un *cambio* único.

| | LockIME | Input Source Pro | KeyboardHolder |
|---|---|---|---|
| Precio | Gratis | Gratis | Gratis (donación) |
| Código abierto | GPL-3.0 | GPL-3.0 | ✗ (cerrado) |
| macOS mínimo | 14 | 11 | 10.15 |
| Tamaño de descarga | < 3 MB | ≈ 7.6 MB | ≈ 4.5 MB |
| Reglas por aplicación | ✓ | ✓ | ✓ |
| Reglas por sitio web / URL | ✓ | ✓ | ✓ |
| Tipos de coincidencia de URL | subdominio · exacto · palabra clave · regex | subdominio · exacto · regex | dominio (comodín) |
| Regla de barra de direcciones (campo de URL) | ✓ (bloqueo/cambio/prioridad) | ✓ (fuente predeterminada) | — |
| Rebloqueo continuo | ✓ | ✗ | ✗ |
| Bloqueo *o* cambio único, por regla | ✓ | ✗ | ✗ |
| Atajos de teclado globales | ✓ | ✓ | ✗ |
| Control desde la barra de menús | ✓ | ✓ | ✓ |
| Indicaciones de entrada en pantalla | ✗ | ✓ | ✓ (opcional) |
| Registro de activaciones de 24 horas | ✓ | ✗ | ✗ |
| Copia de seguridad / importación de la configuración | ✓ (`.lockime`, con revisión) | ✓ (exportación/importación + CLI) | — |
| Automatización con esquema de URL | ✓ (`lockime-voice://`, x-callback-url) | parcial (importación `inputsourcepro://`) | ✗ |
| Idiomas de la interfaz | 9 (cambio en vivo) | 6 | zh · en · ja |
| Permisos del sistema | ninguno para el núcleo · Accessibility para reglas por URL | ninguno para el núcleo · Accessibility para reglas por URL | Accessibility¹ |
| Actualización automática | ✗ (fork solo de código fuente) | ✓ | ✓ |
| Mantenido activamente (2026) | ✓ | ✓ | ✓ |

¹ KeyboardHolder no documenta sus requisitos de permisos; leer la barra de
direcciones del navegador para sus reglas por sitio web requiere acceso a
Accessibility en la práctica. Un «—» marca una capacidad no documentada, no una
ausencia confirmada.

**Cómo elegir entre ellas:** Input Source Pro tiene la comunidad más grande y
las indicaciones de entrada en pantalla más completas; KeyboardHolder es una
memoria por aplicación pulida y sin configuración. Recurre a LockIME cuando
quieras *fijar* una fuente de entrada — por aplicación, por URL o en la barra de
direcciones, vuelta a aplicar en el instante en que algo la cambia — en lugar de
solo cambiarla al llegar.

**Otras herramientas:** [SwitchKey](https://github.com/itsuhane/SwitchKey) (solo
por aplicación, sin mantenimiento), [Kawa](https://github.com/hatashiro/kawa)
(manual, dirigido por atajos), InputSwitcher (freemium, solo por aplicación) y
[macism](https://github.com/laishulu/macism) (un componente de línea de
comandos, no un cambiador con interfaz gráfica).

> Comparado con Input Source Pro 2.11.0 y KeyboardHolder 1.14.10, a mediados de 2026 — los detalles cambian; se agradecen las correcciones.

## Automation

LockIME expone un esquema de URL `lockime-voice://` para que otras aplicaciones, scripts, Shortcuts y lanzadores puedan controlarlo: activarlo o desactivarlo, recambiar la fuente de entrada, gestionar reglas y leer el estado de vuelta con callbacks de [x-callback-url](https://x-callback-url.com). Está desactivada por defecto — actívala en **Ajustes ▸ General ▸ Automatización**.

```sh
open "lockime-voice://lock"
open "lockime-voice://lock-to-source?id=com.apple.keylayout.ABC"
open "lockime-voice://set-app-rule?bundle=com.apple.Terminal&mode=lock&source=com.apple.keylayout.ABC"
```

Referencia completa: **[URL Scheme API](../URL-Scheme-API/README.es.md)**.

## Design

LockIME sigue un único sistema de diseño (`Sources/LockIME/UI/DesignSystem.swift`): los colores semánticos, los materiales del sistema y los SF Symbols dirigen la adaptación claro/oscuro; Liquid Glass se reserva únicamente para la capa flotante/de navegación. El color de acento de la marca, «Lock Indigo», se incluye como asset `AccentColor`. La especificación completa está en [docs/DESIGN.md](../DESIGN.md).

El icono de la aplicación se genera por programa (sin herramienta de diseño) — regenéralo con:

```sh
./scripts/make-appicon.sh   # renders the master via SwiftUI and rebuilds the appiconset
```

## Development

Requiere Xcode 26+ (la propia aplicación apunta a macOS 14+), además de [XcodeGen](https://github.com/yonaskolb/XcodeGen) + [xcbeautify](https://github.com/cpisciotta/xcbeautify) (`brew install xcodegen xcbeautify`).

```sh
make gen     # generate LockIMEVoice.xcodeproj from project.yml
make build   # build (Debug)
make run     # build & launch
make test    # run unit tests
make archive # ad-hoc-signed Release archive
```

El proyecto de Xcode se genera a partir de `project.yml` y no está versionado.

Las pruebas de integración que tocan hardware (cambio real de TIS) están excluidas de `make test`; ejecútalas con `make test-hw` (cambia brevemente la fuente de entrada).

## Releasing

Los DMG preliminares se compilan y suben manualmente. Developer ID, notarización, Sparkle, nightly y Homebrew siguen desactivados. Consulta [docs/RELEASING.md](../RELEASING.md).

## Architecture

- **LockIMEKit** (biblioteca estática) — lógica pura, totalmente cubierta por pruebas unitarias, que solo usa frameworks del sistema: motor de bloqueo, monitor de aplicaciones, reglas, observador mejorado (Accessibility), modelo de registro, localización.
- **LockIME Voice** (aplicación) — `@main`, la interfaz SwiftUI, el sistema de diseño y las finas capas de integración para Sparkle, KeyboardShortcuts y PermissionFlow.

## License

Copyright © 2026 Hangzhou Wumou Software Co., Ltd.

Modifications © 2026 zhangsiqiang519.

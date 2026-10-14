<div align="center">

<img src="../images/appicon.png" alt="LockIME" width="128">

# LockIME Voice

[English](../../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [Français](README.fr.md) · **Deutsch** · [Español](README.es.md) · [Português](README.pt.md) · [Русский](README.ru.md)

[![CI](https://img.shields.io/github/actions/workflow/status/zhangsiqiang519/LockIME-Voice/ci.yml?branch=main&label=CI)](https://github.com/zhangsiqiang519/LockIME-Voice/actions/workflows/ci.yml)
[![Lizenz: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-3A5BD9)](../../LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)

</div>

> **LockIME Voice Quellcode-Fork.** Diese GPL-3.0-Ableitung ergänzt den konfigurierbaren Spracheingabe-Workflow. `v0.1.2` bietet ad-hoc signierte Vorschau-Installer, jedoch keine Developer-ID-Signierung, Notarisierung, Sparkle-Updates oder Homebrew-Verteilung.

Eine macOS-Menüleisten-App, die **deine Tastatur-Eingabequelle sperrt**. Wann immer du (oder eine andere App) die Eingabemethode wechselst, schaltet LockIME sofort auf die gesperrte zurück — global, pro Vordergrund-App oder (mit dem optionalen erweiterten Modus) pro Browser-URL.

> macOS 14+ · Apple silicon & Intel — separate Apps, lade die zu deinem Mac
> passende `-arm64`- oder `-x86_64`-Datei herunter · gebaut mit SwiftUI,
> Liquid Glass unter macOS 26 (Tahoe).

## Screenshots

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-general-en-dark.png">
    <img alt="Allgemeine Einstellungen" src="../images/settings-general-en-light.png" width="32%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-app-rules-en-dark.png">
    <img alt="Regeln pro App" src="../images/settings-app-rules-en-light.png" width="32%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-url-rules-en-dark.png">
    <img alt="Regeln pro URL" src="../images/settings-url-rules-en-light.png" width="32%">
  </picture>
</p>

## Changes in LockIME Voice

Gegenüber dem Upstream ergänzt dieser Fork eine frei wählbare Spracheingabequelle, getrennte Kurzbefehle für LockIME und die Eingabemethode, einen optionalen temporären Wechsel der Eingabequelle während der Spracheingabe (standardmäßig aus), Wiederherstellung der globalen Standardquelle aus **App Rules**, zuverlässige Wiederholungen mit Timeout sowie eine zuerst angezeigte, mit einer Nadel markierte Standardquelle.

![LockIME Voice Spracheingabe-Einstellungen](../images/settings-voice-input-zh-CN.png)

## Install

Lade den passenden Installer:

- [Apple silicon (arm64)](https://github.com/zhangsiqiang519/LockIME-Voice/releases/download/v0.1.2/LockIME-Voice-0.1.2-arm64.dmg)
- [Intel (x86_64)](https://github.com/zhangsiqiang519/LockIME-Voice/releases/download/v0.1.2/LockIME-Voice-0.1.2-x86_64.dmg)

SHA-256-Pruefsummen:

- `LockIME-Voice-0.1.2-arm64.dmg`: `228beeede12dda7f40b3a06da766ee55c1bd356fce889546052d216eaa6e49cd`
- `LockIME-Voice-0.1.2-x86_64.dmg`: `a3359323bf72569dc5885d1c710101651bb4edb052ee38f604bc7a96f43009fa`

Öffne das DMG und ziehe **LockIME Voice** nach Applications. Da die Vorschau ad-hoc signiert und nicht notarisiert ist, öffne die App beim ersten Mal per Rechtsklick → **Open**. Wenn macOS „Apple could not verify..." anzeigt, öffne **System Settings ▸ Privacy & Security**, klicke für **LockIME Voice** auf **Open Anyway**, bestätige den Start und erteile danach **Accessibility** und **Input Monitoring**.

Alternativ aus dem Quellcode bauen:

```sh
brew install xcodegen xcbeautify
make build
open "build/DerivedData/Build/Products/Debug/LockIME Voice Dev.app"
```

Nach einer Neuinstallation oder einem neuen Build können macOS-Berechtigungen erneut nötig sein. Automatische Updates sind nicht verfügbar.

## Features

- **Sofortiges Wieder-Sperren** — schaltet die aktive Eingabequelle in dem Moment zurück, in dem du (oder eine andere App) sie wechselst, global oder pro App.
- **Konfliktbewusst** — wenn ein anderes Programm seine eigene Eingabequelle immer wieder neu durchsetzt (etwa ein Spiel mit eingebauter IME-Verwaltung), erkennt LockIME das Tauziehen und tritt kurz zurück, statt endlos hin- und herzuschalten; im Aktivitätsprotokoll erscheint *Konflikt erkannt*. Gib einer solchen App ihre eigene *Ignorieren*- oder *Wechseln zu*-Regel für eine dauerhafte Lösung.
- **Regeln für Prozesse ohne Bundle** — Programme, die aus einer bloßen ausführbaren Datei statt aus einem `.app`-Bundle laufen (etwa Minecrafts `java`, gestartet von einem Drittanbieter-Launcher), können ebenfalls Regeln bekommen: Solange sie laufen, führt die App-Auswahl sie unter einer synthetischen `process:<executable>`-Identität auf (z. B. `process:java`).
- **Sperren oder wechseln** — Regeln pro App und pro URL können eine Eingabequelle *sperren* (bei jeder Abweichung erneut angewendet) oder einmalig dorthin *wechseln*, sobald du die App oder Seite aktivierst, und dich danach frei wählen lassen.
- **Global sperren oder einfach wechseln** — gib der globalen Standard-Eingabequelle eines von drei Verhalten: *sperren*, um sie überall zu fixieren; *wechseln*, um dich einmalig hineinzuschalten, sobald eine App auf den globalen Standard zurückgreift (sie hat keine eigene Regel oder ihre Regel ist *Standard verwenden*), und dich danach frei wählen zu lassen; oder **Keine** für gar kein globales Verhalten — LockIME wirkt dann nur über deine Regeln pro App und pro URL. *Wechseln* schaltet dich aktiv hinein, sobald der Standard greift; **Keine** tut global nichts.
- **Flexibler URL-Abgleich** — Regeln pro URL (erweiterter Modus) passen über eine Domain und ihre Subdomains, eine exakte Domain, ein Domain-Schlüsselwort oder einen regulären Ausdruck über die vollständige URL und greifen in einer Prioritätsreihenfolge, die du per Ziehen anordnest — der erste Treffer gewinnt.
- **Steuerung über die Menüleiste** — aktivieren/deaktivieren, die gesperrte Eingabequelle wechseln, die aktuelle Eingabequelle einsehen und die Auslösungen direkt in der Menüleiste verfolgen.
- **Tastatur-Kurzbefehle** — konfigurierbare globale Kurzbefehle zum Ein- und Ausschalten von LockIME und zum Durchschalten der gesperrten Eingabequelle sowie App-spezifische Kurzbefehle, um die Regel der vordersten App durchzuschalten oder zu entfernen.
- **Spracheingabe-Workflow** — wechselt vorübergehend von deiner täglichen Eingabequelle zu einer konfigurierten spracheingabefähigen Eingabequelle, sendet den eigenen Sprachkurzbefehl dieser Eingabemethode und stellt danach deine tägliche Eingabequelle wieder her. Verhalten und Kurzbefehl in LockIME müssen zu den Spracheingabe-Einstellungen der gewählten Eingabemethode passen.
- **Start bei Anmeldung** — startet automatisch beim Anmelden (standardmäßig aus).
- **Heller & dunkler Modus** — eine einheitliche, systemnative Designsprache, die sich an helles und dunkles Erscheinungsbild anpasst, plus ein maßgeschneidertes App-Symbol. Siehe [docs/DESIGN.md](../DESIGN.md).
- **Sprachwechsel zur Laufzeit** — wechsle sofort zwischen 9 Sprachen, ohne Neustart: English, 简体中文, 繁體中文, 日本語, Français, Deutsch, Español, Português, Русский.
- **24-Stunden-Aktivitätsprotokoll** — sieh nach, was warum und wie lange zurückgeschaltet wurde.
- **Konfigurations-Backup** — exportiere deine Regeln pro App und pro URL in eine `.lockime`-Datei und importiere sie wieder, mit einem Vorschau-Schritt, der Ergänzungen, Konflikte und Entfernungen auflistet, bevor etwas angewendet wird.
- **Winziger Download** — die gesamte App steckt in einer `.dmg` unter 3 MB.
- **Keine Systemberechtigungen für das Kern-Sperren** — ein optionaler, über Accessibility freigeschalteter erweiterter Modus ermöglicht feinere Regeln pro URL und pro fokussiertem Feld.
- **Automatisierung** — ein `lockime-voice://`-URL-Schema lässt andere Apps, Skripte und Kurzbefehle LockIME steuern (siehe unten).

## Voice Input Workflow

Die Spracheingabequelle ist frei wählbar; LockIME Voice legt weder Doubao noch WeChat oder eine andere Eingabemethode fest.

1. Öffnen Sie **Settings ▸ Voice Input** und aktivieren Sie den Workflow.
2. Erfassen Sie den **Sprachkurzbefehl der Eingabemethode** — den Kurzbefehl, den Ihre Eingabemethode für ihre eigene Spracheingabe verwendet. Legen Sie ihn zuerst dort fest und halten Sie ihn vom Kurzbefehl von LockIME getrennt.
3. Erfassen Sie den **LockIME-Sprachkurzbefehl** (unter **Settings ▸ Shortcuts ▸ Global shortcuts** oder im selben Bereich). Das ist die Taste, die Sie tatsächlich drücken.
4. Optional: Schalten Sie **Eingabequelle automatisch wechseln** ein und wählen Sie die sprachfähige Eingabequelle, wenn diese nicht Ihre alltägliche ist. Legen Sie vorher unter **Settings ▸ App Rules** die globale Standardquelle fest — dorthin stellt LockIME danach zurück.
5. Erlauben Sie bei Aufforderung das Senden von Tastaturereignissen.

Ein Druck auf den LockIME-Kurzbefehl sendet den Sprachkurzbefehl der Eingabemethode, sodass die Spracheingabe in der gerade aktiven Eingabemethode startet. Mit eingeschaltetem automatischem Wechsel wechselt LockIME zuerst zur konfigurierten Spracheingabequelle, wartet auf die Bestätigung von macOS und stellt nach dem Ende der Spracheingabe oder dem Sicherheits-Timeout die globale Standardquelle wieder her.

Da LockIME diesen Kurzbefehl nur *sendet* und Ihre Tastenanschläge nie mitliest, müssen die beiden Kurzbefehle verschieden sein. Eine einzige gemeinsame Kombination bringt den Konflikt zurück: Die Taste wird zweimal verarbeitet und macOS oder die Eingabemethode meldet einen Kurzbefehlskonflikt.

Testen Sie den Workflow in TextEdit oder einem anderen einfachen Textfeld. Das Sprachfenster zu sehen genügt nicht: Der erkannte Text muss an der aktuellen Cursorposition erscheinen.
## Comparison

Die zwei am weitesten verbreiteten Alternativen zu LockIME sind
**[Input Source Pro](https://github.com/runjuu/InputSourcePro)** und
**[KeyboardHolder](https://github.com/leaves615/KeyboardHolder)**, neben einem
langen Schwanz kleinerer Open-Source- und CLI-Tools. Sie alle *wechseln* die
Eingabequelle, während du dich zwischen Apps oder Seiten bewegst; LockIME ist um
eine kontinuierliche **Sperre** herum gebaut, die sie in dem Moment erneut
anwendet, in dem sie abweicht — wobei jede Regel weiterhin auf einen einmaligen
*Wechsel* zurückfallen kann.

| | LockIME | Input Source Pro | KeyboardHolder |
|---|---|---|---|
| Preis | Kostenlos | Kostenlos | Kostenlos (Spende) |
| Open Source | GPL-3.0 | GPL-3.0 | ✗ (geschlossen) |
| Mindest-macOS | 14 | 11 | 10.15 |
| Download-Größe | < 3 MB | ≈ 7.6 MB | ≈ 4.5 MB |
| Regeln pro App | ✓ | ✓ | ✓ |
| Regeln pro Website / URL | ✓ | ✓ | ✓ |
| URL-Abgleichstypen | Subdomain · exakt · Schlüsselwort · Regex | Subdomain · exakt · Regex | Domain (Platzhalter) |
| Adressleisten-Regel (URL-Feld) | ✓ (Sperren/Wechseln/Priorität) | ✓ (Standardquelle) | — |
| Kontinuierliches Wieder-Sperren | ✓ | ✗ | ✗ |
| Sperren *oder* einmaliger Wechsel, pro Regel | ✓ | ✗ | ✗ |
| Globale Tastatur-Kurzbefehle | ✓ | ✓ | ✗ |
| Steuerung über die Menüleiste | ✓ | ✓ | ✓ |
| Eingabe-Hinweise auf dem Bildschirm | ✗ | ✓ | ✓ (optional) |
| 24-Stunden-Aktivitätsprotokoll | ✓ | ✗ | ✗ |
| Konfigurations-Backup / -Import | ✓ (`.lockime`, mit Vorschau) | ✓ (Export/Import + CLI) | — |
| URL-Schema-Automatisierung | ✓ (`lockime-voice://`, x-callback-url) | teilweise (`inputsourcepro://`-Import) | ✗ |
| UI-Sprachen | 9 (Wechsel zur Laufzeit) | 6 | zh · en · ja |
| Systemberechtigungen | keine für den Kern · Accessibility für Regeln pro URL | keine für den Kern · Accessibility für Regeln pro URL | Accessibility¹ |
| Automatische Updates | ✗ (reiner Quellcode-Fork) | ✓ | ✓ |
| Aktiv gepflegt (2026) | ✓ | ✓ | ✓ |

¹ KeyboardHolder dokumentiert seine Berechtigungsanforderungen nicht; das
Auslesen der Browser-Adressleiste für seine Regeln pro Website erfordert in der
Praxis Accessibility-Zugriff. Ein „—" kennzeichnet eine nicht dokumentierte
Fähigkeit, kein bestätigtes Fehlen.

**Die Wahl zwischen ihnen:** Input Source Pro hat die größte Community und die
umfangreichsten Eingabe-Hinweise auf dem Bildschirm; KeyboardHolder ist ein
ausgefeiltes, konfigurationsfreies Gedächtnis pro App. Greife zu LockIME, wenn du
eine Eingabequelle *fixiert* haben möchtest — pro App, pro URL oder in der
Adressleiste, in dem Augenblick erneut angewendet, in dem irgendetwas sie ändert —
statt sie nur umzuschalten, wenn du ankommst.

**Weitere Tools:** [SwitchKey](https://github.com/itsuhane/SwitchKey) (nur pro
App, nicht mehr gepflegt), [Kawa](https://github.com/hatashiro/kawa) (manuell,
kurzbefehlgesteuert), InputSwitcher (Freemium, nur pro App) und
[macism](https://github.com/laishulu/macism) (ein Kommandozeilen-Baustein, kein
GUI-Umschalter).

> Verglichen mit Input Source Pro 2.11.0 und KeyboardHolder 1.14.10, Mitte 2026 — die Angaben verschieben sich; Korrekturen willkommen.

## Automation

LockIME stellt ein `lockime-voice://`-URL-Schema bereit, damit andere Apps, Skripte, Kurzbefehle und Launcher es steuern können — es ein- oder ausschalten, die Eingabequelle neu festlegen, Regeln verwalten und mit [x-callback-url](https://x-callback-url.com)-Rückrufen den Zustand auslesen. Sie ist standardmäßig aus — schalte sie unter **Einstellungen ▸ Allgemein ▸ Automatisierung** ein.

```sh
open "lockime-voice://lock"
open "lockime-voice://lock-to-source?id=com.apple.keylayout.ABC"
open "lockime-voice://set-app-rule?bundle=com.apple.Terminal&mode=lock&source=com.apple.keylayout.ABC"
```

Vollständige Referenz: **[URL Scheme API](../URL-Scheme-API/README.de.md)**.

## Design

LockIME folgt einem einzigen Designsystem (`Sources/LockIME/UI/DesignSystem.swift`): semantische Farben, Systemmaterialien und SF Symbols steuern die Hell/Dunkel-Anpassung; Liquid Glass ist ausschließlich der schwebenden/Navigations-Ebene vorbehalten. Die Marken-Akzentfarbe „Lock Indigo" wird als `AccentColor`-Asset ausgeliefert. Die vollständige Spezifikation steht in [docs/DESIGN.md](../DESIGN.md).

Das App-Symbol wird programmatisch erzeugt (ohne Design-Tool) — regeneriere es mit:

```sh
./scripts/make-appicon.sh   # renders the master via SwiftUI and rebuilds the appiconset
```

## Development

Erfordert Xcode 26+ (die App selbst zielt auf macOS 14+) sowie [XcodeGen](https://github.com/yonaskolb/XcodeGen) + [xcbeautify](https://github.com/cpisciotta/xcbeautify) (`brew install xcodegen xcbeautify`).

```sh
make gen     # generate LockIMEVoice.xcodeproj from project.yml
make build   # build (Debug)
make run     # build & launch
make test    # run unit tests
make archive # ad-hoc-signed Release archive
```

Das Xcode-Projekt wird aus `project.yml` generiert und ist nicht eingecheckt.

Hardware-berührende Integrationstests (echtes TIS-Umschalten) sind von `make test` ausgenommen; führe sie mit `make test-hw` aus (ändert kurzzeitig die Eingabequelle).

## Releasing

Vorschau-DMGs werden manuell gebaut und hochgeladen. Developer ID, Notarisierung, Sparkle, Nightly und Homebrew bleiben deaktiviert. Details stehen in [docs/RELEASING.md](../RELEASING.md).

## Architecture

- **LockIMEKit** (statische Bibliothek) — reine, vollständig unit-getestete Logik, die nur Systemframeworks nutzt: Sperr-Engine, App-Monitor, Regeln, erweiterter (Accessibility-)Beobachter, Protokollmodell, Lokalisierung.
- **LockIME Voice** (App) — `@main`, die SwiftUI-Oberfläche, das Designsystem und die dünnen Integrationsschichten für Sparkle, KeyboardShortcuts und PermissionFlow.

## License

Copyright © 2026 Hangzhou Wumou Software Co., Ltd.

Modifications © 2026 zhangsiqiang519.

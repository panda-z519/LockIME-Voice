<div align="center">

<img src="../images/appicon.png" alt="LockIME" width="128">

# LockIME Voice

[English](../../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · **Français** · [Deutsch](README.de.md) · [Español](README.es.md) · [Português](README.pt.md) · [Русский](README.ru.md)

[![CI](https://img.shields.io/github/actions/workflow/status/panda-z519/LockIME-Voice/ci.yml?branch=main&label=CI)](https://github.com/panda-z519/LockIME-Voice/actions/workflows/ci.yml)
[![Licence : GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-3A5BD9)](../../LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)

</div>

> **Fork source LockIME Voice.** Ce dérivé GPL-3.0 ajoute le workflow de saisie vocale configurable. `v0.1.10` fournit des installateurs de préversion signés ad-hoc, sans Developer ID, notarisation, Sparkle ni Homebrew.

Une application de barre de menus macOS qui **verrouille votre source de saisie clavier**. Chaque fois que vous (ou une autre application) changez de méthode de saisie, LockIME rebascule immédiatement vers celle qui est verrouillée — globalement, par application au premier plan, ou (avec le mode renforcé optionnel) par URL de navigateur.

> macOS 14+ · Apple silicon et Intel — applications séparées, téléchargez le
> fichier `-arm64` ou `-x86_64` correspondant à votre Mac · construite avec
> SwiftUI, Liquid Glass sous macOS 26 (Tahoe).

## Screenshots

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-general-en-dark.png">
    <img alt="Réglages généraux" src="../images/settings-general-en-light.png" width="32%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-app-rules-en-dark.png">
    <img alt="Règles par application" src="../images/settings-app-rules-en-light.png" width="32%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-url-rules-en-dark.png">
    <img alt="Règles par URL" src="../images/settings-url-rules-en-light.png" width="32%">
  </picture>
</p>

## Changes in LockIME Voice

Par rapport à l'upstream, ce fork ajoute une source vocale configurable, un seul raccourci vocal pris en charge par LockIME (la touche est consommée, donc aucun conflit), un changement temporaire de source de saisie pendant la dictée (optionnel, désactivé par défaut), le retour à la source utilisée au moment de l'appui (la valeur globale **App Rules** ne sert que de repli), un appui bref ou maintenu sur la touche vocale, l'arrêt par n'importe quelle autre touche sans écraser le texte reconnu, des sessions répétables avec délai de sécurité, ainsi que la source par défaut placée en tête avec une épingle.

![Réglages de saisie vocale LockIME Voice](../images/settings-voice-input-zh-CN.png)

## Install

Téléchargez l'installateur correspondant :

- [Apple silicon (arm64)](https://github.com/panda-z519/LockIME-Voice/releases/download/v0.1.10/LockIME-Voice-0.1.10-arm64.dmg)
- [Intel (x86_64)](https://github.com/panda-z519/LockIME-Voice/releases/download/v0.1.10/LockIME-Voice-0.1.10-x86_64.dmg)

Vérifiez le téléchargement avant de l'ouvrir. Chaque release publie un
`SHA256SUMS.txt` : l'empreinte correspond donc toujours à l'artefact compilé pour
ce tag (le DMG n'est pas reproductible, aucune empreinte n'est donc figée ici).

```sh
gh release download v0.1.10 --repo panda-z519/LockIME-Voice \
  --pattern 'LockIME-Voice-0.1.10-*.dmg' --pattern SHA256SUMS.txt
shasum -a 256 -c SHA256SUMS.txt
```

C'est cette vérification qui rend « Ouvrir malgré tout » sûr pour une version non
notariée : ne contournez jamais Gatekeeper pour un téléchargement non vérifié.


Ouvrez le DMG et glissez **LockIME Voice** dans Applications. Cet aperçu est uniquement signé ad-hoc et **non notarié** : Gatekeeper bloque donc le premier lancement.

1. Double-cliquez sur **LockIME Voice**. macOS refuse avec *« Apple n'a pas pu vérifier que LockIME Voice ne contient pas de logiciel malveillant »* — c'est normal et ne signifie pas que le téléchargement est corrompu.
2. Ouvrez **Réglages Système ▸ Confidentialité et sécurité** et faites défiler jusqu'à la section **Sécurité**. **LockIME Voice** y figure avec un bouton **Ouvrir malgré tout**.
3. Cliquez sur **Ouvrir malgré tout**, authentifiez-vous, puis confirmez avec **Ouvrir** dans la boîte de dialogue. L'app se lancera normalement par la suite.

Ne faites confiance qu'à une copie téléchargée depuis la page des versions de ce dépôt et dont le SHA-256 correspond à l'empreinte ci-dessus : c'est la condition pour que « Ouvrir malgré tout » soit sûr sur une version non notariée. Après le lancement, accordez **Accessibilité** lorsque macOS le demande (le workflow de saisie vocale en a besoin ; la même fenêtre couvre l'envoi d'événements clavier).

Vous pouvez aussi construire depuis les sources :

```sh
brew install xcodegen xcbeautify
make build
open "build/DerivedData/Build/Products/Debug/LockIME Voice Dev.app"
```

Après réinstallation ou reconstruction, les autorisations peuvent être redemandées. Les mises à jour automatiques ne sont pas disponibles.

## Features

- **Reverrouillage instantané** — rebascule la source de saisie active dès que vous (ou une autre application) la changez, globalement ou par application.
- **Sensible aux conflits** — si un autre programme réimpose sans cesse sa propre source de saisie (par exemple un jeu qui gère lui-même l'IME), LockIME détecte ce bras de fer et s'efface brièvement au lieu de basculer sans fin, en consignant *Conflit détecté* dans le journal d'activation ; donnez à une telle application sa propre règle *Ignorer* ou *Basculer vers* pour un remède durable.
- **Règles pour processus sans bundle** — les programmes qui s'exécutent depuis un simple exécutable plutôt que depuis un bundle `.app` (par exemple le `java` de Minecraft, lancé par un lanceur tiers) peuvent eux aussi recevoir des règles : pendant leur exécution, le sélecteur d'applications les liste sous une identité synthétique `process:<executable>` (par exemple `process:java`).
- **Verrouiller ou basculer** — les règles par application et par URL peuvent *verrouiller* une source de saisie (réappliquée dès qu'elle dévie) ou simplement y *basculer* une fois lorsque vous activez l'application ou la page, puis vous laisser libre de la changer.
- **Verrouiller globalement, ou simplement basculer** — attribuez à la source de saisie par défaut globale l'un des trois comportements : *verrouiller* pour l'épingler partout ; *basculer* pour vous y faire basculer une fois dès qu'une application se rabat sur la valeur par défaut globale, puis vous laisser libre (se redéclenchant à chaque fois) ; ou **Aucune** pour aucun comportement global — LockIME n'agit qu'à travers les règles par application et par URL. *Basculer* vous fait activement basculer chaque fois qu'une application se rabat sur la valeur par défaut globale ; **Aucune** ne fait rien globalement.
- **Correspondance d'URL flexible** — les règles par URL (mode renforcé) correspondent par un domaine et ses sous-domaines, un domaine exact, un mot-clé de domaine, ou une expression régulière sur l'URL entière, et s'appliquent dans un ordre de priorité que vous organisez par glisser-déposer — la première correspondance l'emporte.
- **Contrôle depuis la barre de menus** — activer/désactiver, changer la source de saisie verrouillée, voir la source actuelle et suivre le nombre d'activations depuis la barre de menus.
- **Raccourcis clavier** — des raccourcis globaux configurables pour activer/désactiver LockIME et faire défiler la source de saisie verrouillée, ainsi que des raccourcis par application pour faire défiler ou supprimer la règle de l’application au premier plan.
- **Flux de saisie vocale** — basculez temporairement de votre source de saisie quotidienne vers une source configurée pour la voix, envoyez le raccourci vocal propre à cette méthode de saisie, puis restaurez votre source quotidienne. Le comportement et le raccourci configurés dans LockIME doivent correspondre aux réglages de saisie vocale de la méthode de saisie sélectionnée.
- **Lancement à la connexion** — démarre automatiquement à l'ouverture de session (désactivé par défaut).
- **Mode clair et sombre** — un langage de design unifié et natif du système, qui s'adapte aux apparences claire et sombre, avec une icône d'application sur mesure. Voir [docs/DESIGN.md](../DESIGN.md).
- **Changement de langue à chaud** — basculez instantanément entre 9 langues, sans redémarrage : English, 简体中文, 繁體中文, 日本語, Français, Deutsch, Español, Português, Русский.
- **Journal d'activation sur 24 heures** — consultez ce qui a été rebasculé, pourquoi, et pendant combien de temps.
- **Sauvegarde de la configuration** — exportez vos règles par application et par URL dans un fichier `.lockime`, puis réimportez-les, avec une étape de prévisualisation qui liste les ajouts, les conflits et les suppressions avant toute application.
- **Téléchargement minuscule** — toute l'application tient dans un `.dmg` de moins de 3 MB.
- **Aucune permission système pour le verrouillage de base** — un mode renforcé optionnel, soumis à l'autorisation Accessibility, débloque des règles plus fines par URL et par champ ayant le focus.
- **Automatisation** — un schéma d'URL `lockime-voice://` permet à d'autres applications, scripts et Shortcuts de piloter LockIME (voir ci-dessous).

## Voice Input Workflow

La source de saisie vocale est entièrement configurable ; LockIME Voice n'impose ni Doubao, ni WeChat, ni aucune autre méthode de saisie.

1. Ouvrez **Settings ▸ Voice Input** et activez le workflow.
2. Enregistrez le **raccourci vocal** — celui que vous utilisez pour la dictée dans votre méthode de saisie. LockIME prend cette touche en charge.
3. Facultatif : choisissez une source vocale et activez le changement automatique.
4. Accordez **Accessibilité**. Elle est nécessaire pour que LockIME prenne le raccourci vocal en charge ; sans elle, la touche parvient à la méthode de saisie et macOS signale de nouveau un conflit de raccourcis. Le verrouillage principal reste sans autorisation.

### Pourquoi il n'y a plus de conflit

LockIME consomme la touche vocale : votre méthode de saisie ne voit donc jamais l'appui physique — il n'y a plus rien avec quoi entrer en conflit. LockIME renvoie ensuite cette même touche pour démarrer et arrêter la dictée, marquée afin que son propre écouteur ignore l'écho.

C'est la différence avec l'ancien modèle à deux raccourcis, qui vous demandait d'en maintenir deux distincts tout en laissant la méthode de saisie réagir à sa propre touche.

Testez le workflow dans TextEdit ou un autre champ de texte simple. Voir le panneau vocal ne suffit pas : le texte reconnu doit apparaître à la position du curseur.
## Comparison

Les deux alternatives à LockIME les plus utilisées sont
**[Input Source Pro](https://github.com/runjuu/InputSourcePro)** et
**[KeyboardHolder](https://github.com/leaves615/KeyboardHolder)**, aux côtés
d'une longue série d'outils open-source et CLI plus modestes. Tous *basculent*
la source de saisie à mesure que vous passez d'une application ou d'un site à
l'autre ; LockIME est conçue autour d'un **verrouillage** continu qui la
réapplique dès qu'elle dévie — tandis que chaque règle peut tout de même se
rabattre sur une *bascule* unique.

| | LockIME | Input Source Pro | KeyboardHolder |
|---|---|---|---|
| Prix | Gratuit | Gratuit | Gratuit (don) |
| Open source | GPL-3.0 | GPL-3.0 | ✗ (fermé) |
| macOS minimum | 14 | 11 | 10.15 |
| Taille de téléchargement | < 3 MB | ≈ 7.6 MB | ≈ 4.5 MB |
| Règles par application | ✓ | ✓ | ✓ |
| Règles par site / URL | ✓ | ✓ | ✓ |
| Types de correspondance d'URL | sous-domaine · exact · mot-clé · regex | sous-domaine · exact · regex | domaine (joker) |
| Règle de barre d'adresse (champ URL) | ✓ (verrouillage/bascule/priorité) | ✓ (source par défaut) | — |
| Reverrouillage continu | ✓ | ✗ | ✗ |
| Verrouiller *ou* basculer une fois, par règle | ✓ | ✗ | ✗ |
| Raccourcis clavier globaux | ✓ | ✓ | ✗ |
| Contrôle depuis la barre de menus | ✓ | ✓ | ✓ |
| Indications de saisie à l'écran | ✗ | ✓ | ✓ (optionnel) |
| Journal d'activation sur 24 heures | ✓ | ✗ | ✗ |
| Sauvegarde / import de la configuration | ✓ (`.lockime`, avec prévisualisation) | ✓ (export/import + CLI) | — |
| Automatisation par schéma d'URL | ✓ (`lockime-voice://`, x-callback-url) | partiel (import `inputsourcepro://`) | ✗ |
| Langues de l'interface | 9 (changement à chaud) | 6 | zh · en · ja |
| Permissions système | aucune pour le cœur · Accessibility par URL | aucune pour le cœur · Accessibility par URL | Accessibility¹ |
| Mise à jour automatique | ✗ (fork source uniquement) | ✓ | ✓ |
| Activement maintenu (2026) | ✓ | ✓ | ✓ |

¹ KeyboardHolder ne documente pas ses exigences en matière de permissions ; la
lecture de la barre d'adresse du navigateur pour ses règles par site nécessite
en pratique l'accès Accessibility. Un « — » signale une capacité non
documentée, et non une absence confirmée.

**Choisir entre eux :** Input Source Pro possède la plus grande communauté et
les indications de saisie à l'écran les plus riches ; KeyboardHolder est une
mémoire par application soignée et sans configuration. Tournez-vous vers LockIME
lorsque vous voulez *épingler* une source de saisie — par application, par URL
ou dans la barre d'adresse, réappliquée dès que quoi que ce soit la change —
plutôt que seulement la basculer à votre arrivée.

**Autres outils :** [SwitchKey](https://github.com/itsuhane/SwitchKey)
(uniquement par application, non maintenu), [Kawa](https://github.com/hatashiro/kawa)
(manuel, piloté par raccourci), InputSwitcher (freemium, uniquement par
application), et [macism](https://github.com/laishulu/macism) (une brique en
ligne de commande, pas un commutateur graphique).

> Comparaison effectuée avec Input Source Pro 2.11.0 et KeyboardHolder 1.14.10, à la mi-2026 — les détails évoluent ; les corrections sont les bienvenues.

## Automation

LockIME expose un schéma d'URL `lockime-voice://` afin que d'autres applications, scripts, Shortcuts et lanceurs puissent le piloter — l'activer ou le désactiver, recibler la source de saisie, gérer les règles et relire l'état grâce aux rappels [x-callback-url](https://x-callback-url.com). Elle est désactivée par défaut — activez-la dans **Réglages ▸ Général ▸ Automatisation**.

```sh
open "lockime-voice://lock"
open "lockime-voice://lock-to-source?id=com.apple.keylayout.ABC"
open "lockime-voice://set-app-rule?bundle=com.apple.Terminal&mode=lock&source=com.apple.keylayout.ABC"
```

Référence complète : **[URL Scheme API](../URL-Scheme-API/README.fr.md)**.

## Design

LockIME suit un système de design unique (`Sources/LockIME/UI/DesignSystem.swift`) : couleurs sémantiques, matériaux système et SF Symbols pilotent l'adaptation clair/sombre ; Liquid Glass est réservé à la couche flottante/de navigation. La couleur d'accent de la marque, « Lock Indigo », est fournie en tant qu'asset `AccentColor`. La spécification complète se trouve dans [docs/DESIGN.md](../DESIGN.md).

L'icône de l'application est générée par programme (sans outil de design) — régénérez-la avec :

```sh
./scripts/make-appicon.sh   # renders the master via SwiftUI and rebuilds the appiconset
```

## Development

Nécessite Xcode 26+ (l'application elle-même cible macOS 14+), ainsi que [XcodeGen](https://github.com/yonaskolb/XcodeGen) + [xcbeautify](https://github.com/cpisciotta/xcbeautify) (`brew install xcodegen xcbeautify`).

```sh
make gen     # generate LockIMEVoice.xcodeproj from project.yml
make build   # build (Debug)
make run     # build & launch
make test    # run unit tests
make archive # ad-hoc-signed Release archive
```

Le projet Xcode est généré à partir de `project.yml` et n'est pas versionné.

Les tests d'intégration touchant au matériel (bascule TIS réelle) sont exclus de `make test` ; lancez-les avec `make test-hw` (change brièvement la source de saisie).

## Releasing

Les DMG de préversion sont construits et téléversés manuellement. Developer ID, notarisation, Sparkle, nightly et Homebrew restent désactivés. Consultez [docs/RELEASING.md](../RELEASING.md).

## Architecture

- **LockIMEKit** (bibliothèque statique) — logique pure, entièrement couverte par des tests unitaires, n'utilisant que les frameworks système : moteur de verrouillage, moniteur d'applications, règles, observateur renforcé (Accessibility), modèle de journalisation, localisation.
- **LockIME Voice** (application) — `@main`, l'interface SwiftUI, le système de design, et les fines couches d'intégration pour Sparkle, KeyboardShortcuts et PermissionFlow.

## License

Copyright © 2026 Hangzhou Wumou Software Co., Ltd.

Modifications © 2026 zhangsiqiang519.

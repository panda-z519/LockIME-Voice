<div align="center">

<img src="../images/appicon.png" alt="LockIME" width="128">

# LockIME Voice

[English](../../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · **Português** · [Русский](README.ru.md)

[![CI](https://img.shields.io/github/actions/workflow/status/zhangsiqiang519/LockIME-Voice/ci.yml?branch=main&label=CI)](https://github.com/panda-z519/LockIME-Voice/actions/workflows/ci.yml)
[![Licença: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-3A5BD9)](../../LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)

</div>

> **Fork de código-fonte LockIME Voice.** Este derivado GPL-3.0 adiciona o fluxo configurável de entrada por voz. `v0.1.3` oferece instaladores de prévia com assinatura ad-hoc, sem Developer ID, notarização, Sparkle ou Homebrew.

Um app de barra de menus para macOS que **bloqueia a sua fonte de entrada do teclado**. Sempre que você (ou outro app) troca o método de entrada, o LockIME volta imediatamente para o que está bloqueado — globalmente, por app em primeiro plano, ou (com o modo aprimorado opcional) por URL do navegador.

> macOS 14+ · Apple silicon e Intel — apps separados, baixe o arquivo
> `-arm64` ou `-x86_64` correspondente ao seu Mac · construído com SwiftUI,
> Liquid Glass no macOS 26 (Tahoe).

## Screenshots

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-general-en-dark.png">
    <img alt="Ajustes gerais" src="../images/settings-general-en-light.png" width="32%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-app-rules-en-dark.png">
    <img alt="Regras por app" src="../images/settings-app-rules-en-light.png" width="32%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-url-rules-en-dark.png">
    <img alt="Regras por URL" src="../images/settings-url-rules-en-light.png" width="32%">
  </picture>
</p>

## Changes in LockIME Voice

Em relação ao upstream, este fork adiciona fonte de voz configurável, atalhos separados para o LockIME e o método de entrada, troca temporária da fonte de entrada durante a voz (opcional, desativada por padrão), restauração do padrão global de **App Rules**, sessões repetíveis com timeout e a fonte padrão primeiro com um marcador de alfinete.

![Configurações de entrada por voz do LockIME Voice](../images/settings-voice-input-zh-CN.png)

## Install

Baixe o instalador correspondente:

- [Apple silicon (arm64)](https://github.com/panda-z519/LockIME-Voice/releases/download/v0.1.3/LockIME-Voice-0.1.3-arm64.dmg)
- [Intel (x86_64)](https://github.com/panda-z519/LockIME-Voice/releases/download/v0.1.3/LockIME-Voice-0.1.3-x86_64.dmg)

Verifique o download antes de abri-lo. Cada release publica um `SHA256SUMS.txt`,
então o checksum sempre corresponde ao artefato compilado para aquela tag (o DMG
não é reproduzível, por isso nenhum fica fixado aqui):

```sh
gh release download v0.1.3 --repo panda-z519/LockIME-Voice \
  --pattern 'LockIME-Voice-0.1.3-*.dmg' --pattern SHA256SUMS.txt
shasum -a 256 -c SHA256SUMS.txt
```

É essa verificação que torna seguro clicar em **Abrir Mesmo Assim** em uma
compilação sem notarização: nunca contorne o Gatekeeper para um download não verificado.


Abra o DMG e arraste **LockIME Voice** para Aplicativos. Esta pré-visualização é apenas assinada ad-hoc e **não notarizada**, então o Gatekeeper bloqueia a primeira inicialização:

1. Dê um duplo clique em **LockIME Voice**. O macOS recusa com *"A Apple não pôde verificar se o LockIME Voice está livre de malware"* — isso é esperado e não indica um download corrompido.
2. Abra **Ajustes do Sistema ▸ Privacidade e Segurança** e role até a seção **Segurança**. O **LockIME Voice** aparece lá com o botão **Abrir Mesmo Assim**.
3. Clique em **Abrir Mesmo Assim**, autentique-se e confirme com **Abrir** na caixa de diálogo seguinte. A partir daí o app inicia normalmente.

Confie apenas em uma cópia baixada da página de releases deste repositório e cujo SHA-256 corresponda ao checksum acima — é isso que torna seguro clicar em "Abrir Mesmo Assim" em uma compilação sem notarização. Após iniciar, conceda **Acessibilidade** quando solicitado (o fluxo de entrada por voz precisa dela; a mesma janela também cobre o envio de eventos de teclado).

Também é possível compilar do código:

```sh
brew install xcodegen xcbeautify
make build
open "build/DerivedData/Build/Products/Debug/LockIME Voice Dev.app"
```

Após reinstalar ou recompilar, talvez seja necessário conceder as permissões novamente. Não há atualização automática.

## Features

- **Rebloqueio instantâneo** — devolve a fonte de entrada ativa para a bloqueada no momento em que você (ou outro app) a troca, globalmente ou por app.
- **Detecção de conflitos** — se outro programa reimpõe repetidamente a própria fonte de entrada (por exemplo, um jogo com gestão de IME integrada), o LockIME percebe o cabo de guerra e recua por um instante em vez de alternar sem fim, registrando *Conflito detectado* no registro de ativações; dê a esse app uma regra própria de *Ignorar* ou *Alternar para* para uma solução duradoura.
- **Regras para processos avulsos** — programas que rodam a partir de um executável avulso em vez de um bundle `.app` (por exemplo, o `java` do Minecraft, iniciado por um launcher de terceiros) também podem receber regras: enquanto estão em execução, o seletor de apps os lista sob uma identidade sintética `process:<executable>` (por exemplo, `process:java`).
- **Bloquear ou alternar** — as regras por app e por URL podem *bloquear* uma fonte de entrada (reaplicada sempre que ela desvia) ou apenas *alternar* para ela uma vez quando você foca o app ou a página, deixando você livre para mudá-la depois.
- **Bloquear globalmente, ou apenas alternar** — dê à fonte de entrada padrão global um de três comportamentos: *bloquear* para fixá-la em todo lugar; *alternar* para alternar você para ela uma vez sempre que um app recorre ao padrão global, depois deixá-lo livre (disparando de novo cada vez que um app recorre ao padrão global); ou **Nenhuma** para nenhum comportamento global — o LockIME age apenas através de regras por app e por URL. *Alternar* alterna você ativamente sempre que um app recorre ao padrão global; **Nenhuma** não faz nada globalmente.
- **Correspondência flexível de URL** — as regras por URL (modo aprimorado) correspondem por um domínio e seus subdomínios, por um domínio exato, por uma palavra-chave de domínio, ou por uma expressão regular sobre a URL inteira, e se aplicam em uma ordem de prioridade que você arrasta para organizar — a primeira correspondência vence.
- **Controle pela barra de menus** — ative/desative, troque a fonte de entrada bloqueada, veja a fonte atual e acompanhe o contador de ativações pela barra de menus.
- **Atalhos de teclado** — atalhos globais configuráveis para ativar/desativar o LockIME e percorrer a fonte de entrada bloqueada, além de atalhos por app para percorrer ou remover a regra do app em primeiro plano.
- **Fluxo de entrada por voz** — alterne temporariamente da sua fonte de entrada diária para uma fonte configurada com voz, envie o atalho de voz próprio desse método de entrada e depois restaure sua fonte diária. O comportamento e o atalho configurados no LockIME devem corresponder aos ajustes de entrada por voz do método de entrada selecionado.
- **Iniciar no login** — inicia automaticamente quando você faz login (desativado por padrão).
- **Modo claro e escuro** — uma linguagem de design unificada e nativa do sistema, que se adapta às aparências clara e escura, além de um ícone de app sob medida. Veja [docs/DESIGN.md](../DESIGN.md).
- **Troca de idioma ao vivo** — alterne instantaneamente entre 9 idiomas, sem reiniciar: English, 简体中文, 繁體中文, 日本語, Français, Deutsch, Español, Português, Русский.
- **Registro de ativações de 24 horas** — veja o que foi trocado, por quê e por quanto tempo.
- **Backup da configuração** — exporte suas regras por app e por URL para um arquivo `.lockime` e importe-as de volta, com uma etapa de prévia que lista adições, conflitos e remoções antes de aplicar qualquer coisa.
- **Download minúsculo** — o app inteiro cabe em um `.dmg` com menos de 3 MB.
- **Sem permissões do sistema para o bloqueio básico** — um modo aprimorado opcional, condicionado à permissão de Accessibility, libera regras mais finas por URL e por campo em foco.
- **Automação** — um esquema de URL `lockime-voice://` permite que outros apps, scripts e o Shortcuts controlem o LockIME (veja abaixo).

## Voice Input Workflow

A fonte de entrada por voz é totalmente configurável; o LockIME Voice não fixa Doubao, WeChat nem qualquer outro método de entrada.

1. Abra **Settings ▸ Voice Input** e ative o fluxo de trabalho.
2. Grave o **atalho de voz do método de entrada** — o atalho que o seu método de entrada usa para a própria função de voz. Defina-o primeiro dentro do método de entrada e mantenha-o diferente do atalho do LockIME.
3. Grave o **atalho de voz do LockIME** (em **Settings ▸ Shortcuts ▸ Global shortcuts** ou no mesmo painel). É essa a tecla que você realmente pressiona.
4. Opcional: ative **Trocar a fonte de entrada automaticamente** e escolha a fonte com voz, caso não seja a que você usa no dia a dia. Defina antes a fonte padrão global em **Settings ▸ App Rules**: é ela que o LockIME restaura depois.
5. Conceda permissão para enviar eventos de teclado quando for solicitado.

Pressionar o atalho do LockIME envia o atalho de voz do método de entrada, então a entrada por voz começa no método ativo. Com a troca automática ativada, o LockIME muda primeiro para a fonte de voz configurada, aguarda a confirmação do macOS e restaura a fonte padrão global quando a voz termina ou o tempo limite de segurança dispara.

Como o LockIME apenas *envia* esse atalho e nunca escuta suas teclas, os dois atalhos precisam ser combinações diferentes. Usar uma única combinação traz o conflito de volta: a tecla é processada duas vezes e o macOS ou o método de entrada avisa de um conflito de atalhos.

Teste o fluxo no TextEdit ou em outro campo de texto simples. Ver o painel de voz não basta: o texto reconhecido precisa aparecer na posição atual do cursor.
## Comparison

As duas alternativas ao LockIME mais usadas são o **[Input Source Pro](https://github.com/runjuu/InputSourcePro)** e o **[KeyboardHolder](https://github.com/leaves615/KeyboardHolder)**, ao lado de uma longa cauda de ferramentas menores de código aberto e de linha de comando. Todas elas *alternam* a fonte de entrada conforme você se move entre apps ou sites; o LockIME é construído em torno de um **bloqueio** contínuo que a reaplica no momento em que ela desvia — ao mesmo tempo em que qualquer regra ainda pode recorrer a uma *alternância* única.

| | LockIME | Input Source Pro | KeyboardHolder |
|---|---|---|---|
| Preço | Grátis | Grátis | Grátis (doação) |
| Código aberto | GPL-3.0 | GPL-3.0 | ✗ (fechado) |
| macOS mínimo | 14 | 11 | 10.15 |
| Tamanho do download | < 3 MB | ≈ 7.6 MB | ≈ 4.5 MB |
| Regras por app | ✓ | ✓ | ✓ |
| Regras por site / URL | ✓ | ✓ | ✓ |
| Tipos de correspondência de URL | subdomínio · exato · palavra-chave · regex | subdomínio · exato · regex | domínio (curinga) |
| Regra da barra de endereços (campo de URL) | ✓ (bloqueio/alternância/prioridade) | ✓ (fonte padrão) | — |
| Rebloqueio contínuo | ✓ | ✗ | ✗ |
| Bloquear *ou* alternar uma vez, por regra | ✓ | ✗ | ✗ |
| Atalhos de teclado globais | ✓ | ✓ | ✗ |
| Controle pela barra de menus | ✓ | ✓ | ✓ |
| Dicas de entrada na tela | ✗ | ✓ | ✓ (opcional) |
| Registro de ativações de 24 horas | ✓ | ✗ | ✗ |
| Backup / importação da configuração | ✓ (`.lockime`, com prévia) | ✓ (exportar/importar + CLI) | — |
| Automação por esquema de URL | ✓ (`lockime-voice://`, x-callback-url) | parcial (importação `inputsourcepro://`) | ✗ |
| Idiomas da interface | 9 (troca ao vivo) | 6 | zh · en · ja |
| Permissões do sistema | nenhuma para o básico · Accessibility por URL | nenhuma para o básico · Accessibility por URL | Accessibility¹ |
| Atualização automática | ✗ (fork somente de código-fonte) | ✓ | ✓ |
| Mantido ativamente (2026) | ✓ | ✓ | ✓ |

¹ O KeyboardHolder não documenta seus requisitos de permissão; ler a barra de endereços do navegador para suas regras por site exige acesso de Accessibility na prática. Um "—" marca uma capacidade não documentada, não uma ausência confirmada.

**Escolhendo entre eles:** o Input Source Pro tem a maior comunidade e as dicas de entrada na tela mais ricas; o KeyboardHolder é uma memória por app refinada e sem configuração. Recorra ao LockIME quando você quer uma fonte de entrada *fixada* — por app, por URL ou na barra de endereços, reaplicada no instante em que qualquer coisa a muda — em vez de apenas alternada quando você chega.

**Outras ferramentas:** [SwitchKey](https://github.com/itsuhane/SwitchKey) (apenas por app, sem manutenção), [Kawa](https://github.com/hatashiro/kawa) (manual, acionado por atalhos), InputSwitcher (freemium, apenas por app) e [macism](https://github.com/laishulu/macism) (um bloco de construção de linha de comando, não um alternador com interface gráfica).

> Comparado com o Input Source Pro 2.11.0 e o KeyboardHolder 1.14.10, em meados de 2026 — os detalhes mudam; correções são bem-vindas.

## Automation

O LockIME expõe um esquema de URL `lockime-voice://` para que outros apps, scripts, o Shortcuts e launchers possam controlá-lo — ativá-lo ou desativá-lo, redirecionar a fonte de entrada, gerenciar regras e ler o estado de volta com callbacks [x-callback-url](https://x-callback-url.com). Ela está desativada por padrão — ative-a em **Ajustes ▸ Geral ▸ Automação**.

```sh
open "lockime-voice://lock"
open "lockime-voice://lock-to-source?id=com.apple.keylayout.ABC"
open "lockime-voice://set-app-rule?bundle=com.apple.Terminal&mode=lock&source=com.apple.keylayout.ABC"
```

Referência completa: **[URL Scheme API](../URL-Scheme-API/README.pt.md)**.

## Design

O LockIME segue um único sistema de design (`Sources/LockIME/UI/DesignSystem.swift`): cores semânticas, materiais do sistema e SF Symbols conduzem a adaptação claro/escuro; o Liquid Glass fica reservado apenas à camada flutuante/de navegação. A cor de destaque da marca, "Lock Indigo", é distribuída como asset `AccentColor`. A especificação completa está em [docs/DESIGN.md](../DESIGN.md).

O ícone do app é gerado programaticamente (sem ferramenta de design) — regenere-o com:

```sh
./scripts/make-appicon.sh   # renders the master via SwiftUI and rebuilds the appiconset
```

## Development

Requer Xcode 26+ (o app em si tem como alvo o macOS 14+), além de [XcodeGen](https://github.com/yonaskolb/XcodeGen) + [xcbeautify](https://github.com/cpisciotta/xcbeautify) (`brew install xcodegen xcbeautify`).

```sh
make gen     # generate LockIMEVoice.xcodeproj from project.yml
make build   # build (Debug)
make run     # build & launch
make test    # run unit tests
make archive # ad-hoc-signed Release archive
```

O projeto do Xcode é gerado a partir de `project.yml` e não é versionado.

Os testes de integração que tocam o hardware (troca real de TIS) estão excluídos do `make test`; execute-os com `make test-hw` (muda brevemente a fonte de entrada).

## Releasing

Os DMGs de prévia são compilados e enviados manualmente. Developer ID, notarização, Sparkle, nightly e Homebrew continuam desativados. Consulte [docs/RELEASING.md](../RELEASING.md).

## Architecture

- **LockIMEKit** (biblioteca estática) — lógica pura, totalmente coberta por testes unitários, usando apenas frameworks do sistema: motor de bloqueio, monitor de apps, regras, observador aprimorado (Accessibility), modelo de registro, localização.
- **LockIME Voice** (app) — `@main`, a interface SwiftUI, o sistema de design e as finas camadas de integração para Sparkle, KeyboardShortcuts e PermissionFlow.

## License

Copyright © 2026 Hangzhou Wumou Software Co., Ltd.

Modifications © 2026 zhangsiqiang519.

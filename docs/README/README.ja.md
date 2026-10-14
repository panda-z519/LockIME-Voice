<div align="center">

<img src="../images/appicon.png" alt="LockIME" width="128">

# LockIME Voice

[English](../../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · **日本語** · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [Português](README.pt.md) · [Русский](README.ru.md)

[![CI](https://img.shields.io/github/actions/workflow/status/zhangsiqiang519/LockIME-Voice/ci.yml?branch=main&label=CI)](https://github.com/zhangsiqiang519/LockIME-Voice/actions/workflows/ci.yml)
[![ライセンス: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-3A5BD9)](../../LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)

</div>

> **LockIME Voice ソースフォーク。** この GPL-3.0 派生版は、設定可能な音声入力ワークフローを追加します。`v0.1.2` は ad-hoc 署名のプレビューインストーラーを提供しますが、Developer ID 署名、公証、Sparkle 更新、Homebrew 配布はありません。

**キーボードの入力ソースをロックする** macOS メニューバーアプリ。あなた（または他のアプリ）が入力メソッドを切り替えるたびに、LockIME はロック中の入力ソースへ即座に切り戻します——グローバルに、最前面のアプリごとに、あるいは（オプションの拡張モードでは）ブラウザの URL ごとに。

> macOS 14+ · Apple silicon と Intel に対応——2 つの独立したアプリです。
> お使いの Mac に合った `-arm64` または `-x86_64` ファイルをダウンロード
> してください · SwiftUI 製、macOS 26 (Tahoe) では Liquid Glass を採用。

## Screenshots

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-general-en-dark.png">
    <img alt="一般設定" src="../images/settings-general-en-light.png" width="32%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-app-rules-en-dark.png">
    <img alt="アプリごとのルール" src="../images/settings-app-rules-en-light.png" width="32%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-url-rules-en-dark.png">
    <img alt="URL ごとのルール" src="../images/settings-url-rules-en-light.png" width="32%">
  </picture>
</p>

## Changes in LockIME Voice

Upstream と比べ、このフォークは設定可能な音声入力ソース、LockIME 自身の音声ショートカットと入力メソッド内部の音声ショートカットを分離した構成、音声期間中だけ入力を引き継ぐ一時的な入力ソース切り替え（既定はオフ）、**App Rules** のグローバル既定値への復元、タイムアウトによる繰り返し利用の安定化、既定ソースを先頭に表示するピン表示を追加します。

![LockIME Voice 音声入力設定](../images/settings-voice-input-zh-CN.png)

## Install

Mac に合うインストーラーをダウンロードします：

- [Apple silicon (arm64)](https://github.com/zhangsiqiang519/LockIME-Voice/releases/download/v0.1.2/LockIME-Voice-0.1.2-arm64.dmg)
- [Intel (x86_64)](https://github.com/zhangsiqiang519/LockIME-Voice/releases/download/v0.1.2/LockIME-Voice-0.1.2-x86_64.dmg)

SHA-256 チェックサム:

- `LockIME-Voice-0.1.2-arm64.dmg`: `228beeede12dda7f40b3a06da766ee55c1bd356fce889546052d216eaa6e49cd`
- `LockIME-Voice-0.1.2-x86_64.dmg`: `a3359323bf72569dc5885d1c710101651bb4edb052ee38f604bc7a96f43009fa`

DMG を開き、**LockIME Voice** を Applications へドラッグします。プレビューは ad-hoc 署名で未公証のため、初回は右クリック → **Open** を選びます。macOS に「Apple は検証できません...」と表示された場合は、**System Settings ▸ Privacy & Security** を開き、**LockIME Voice** の **Open Anyway** をクリックして起動を確認してから、**Accessibility** と **Input Monitoring** を付与してください。

ソースからのビルドも可能です：

```sh
brew install xcodegen xcbeautify
make build
open "build/DerivedData/Build/Products/Debug/LockIME Voice Dev.app"
```

再インストールや再ビルド後は権限の再許可が必要になる場合があります。自動更新はありません。

## Features

- **即時再ロック**——あなた（または他のアプリ）が入力ソースを切り替えた瞬間に、ロック中のものへ切り戻します。グローバルにも、アプリごとにも。
- **競合への配慮**——別のプログラム（たとえば IME 管理機能を内蔵したゲーム）が自分の入力ソースを繰り返し設定し直す場合、LockIME はその綱引きを察知し、延々と切り替え合戦を続ける代わりに少しのあいだ身を引きます。作動ログには*競合を検出*と記録されます。そうしたアプリには*無視*または*切り替え先*のルールを与えれば恒久的に解決します。
- **素の実行ファイルのルール**——`.app` バンドルではなく素の実行ファイルから動くプログラム（たとえばサードパーティのランチャーから起動される Minecraft の `java`）にもルールを設定できます。実行中のあいだ、アプリピッカーには合成された `process:<executable>` という識別子（例：`process:java`）で一覧表示されます。
- **ロックまたは切り替え**——アプリごと・URL ごとのルールは、入力ソースを*ロック*（ずれるたびに切り戻す）することも、アプリやページをアクティブにしたときに一度だけ*切り替え*て、その後は自由に変更できるようにすることもできます。
- **グローバルにロック、または切り替えだけ**——グローバルのデフォルト入力ソースに、3 つの挙動のいずれかを与えられます：*ロック*はどこでもそれを固定します。*切り替え*は、アプリがグローバルのデフォルトにフォールバックするたびに一度だけそれへ切り替えてから自由にさせます（独自のルールを持たないアプリだけでなく、ルールが*デフォルトを使用*のアプリも対象です）。**なし**はグローバルな挙動を一切持たず、LockIME はアプリごと・URL ごとのルールを通じてのみ作用します。
- **柔軟な URL マッチング**——URL ごとのルール（拡張モード）は、ドメインとそのサブドメイン、完全一致のドメイン、ドメインのキーワード、または URL 全体に対する正規表現でマッチし、ドラッグして並べ替える優先順位順に適用されます——最初にマッチしたものが優先されます。
- **メニューバーからの操作**——メニューバーから有効化/無効化、ロック中の入力ソースの切り替え、現在の入力ソースの確認、作動回数の追跡。
- **キーボードショートカット**——設定可能なグローバルショートカットで LockIME のオン/オフやロック中の入力ソースの切り替え（前 / 次）ができ、さらに最前面のアプリのルールを切り替えたり解除したりするアプリごとのショートカットも利用できます。
- **音声入力ワークフロー**——日常の入力ソースから、設定済みの音声対応入力ソースへ一時的に切り替え、その入力メソッド自身の音声ショートカットを送信してから、日常の入力ソースへ戻します。LockIME で設定する挙動とショートカットは、選択した入力メソッド自身の音声入力設定と一致している必要があります。
- **ログイン時に起動**——ログイン時に自動的に起動（デフォルトはオフ）。
- **ライト & ダークモード**——ライト/ダーク外観に適応する、統一されたシステムネイティブなデザイン言語と、専用のアプリアイコン。[docs/DESIGN.md](../DESIGN.md) を参照。
- **ライブ言語切り替え**——9 言語を再起動なしで即座に切り替え：English、简体中文、繁體中文、日本語、Français、Deutsch、Español、Português、Русский。
- **24 時間の作動ログ**——何が、なぜ、どれだけの時間切り替えられたかを確認できます。
- **設定のバックアップ**——アプリごと・URL ごとのルールを `.lockime` ファイルに書き出し、また読み込めます。読み込み前にはプレビュー画面で、追加・競合・削除を確認してから適用します。
- **小さなダウンロード**——アプリ全体が 3 MB 未満の `.dmg` に収まります。
- **コアのロックにシステム権限は不要**——オプションの Accessibility 権限付き拡張モードで、より細かい URL ごと / フォーカス中フィールドごとのルールが使えます。
- **自動化**——`lockime-voice://` URL スキームにより、他のアプリ・スクリプト・ショートカットから LockIME を操作できます（下記参照）。

## Voice Input Workflow

音声入力用の入力メソッドは自由に設定できます。LockIME Voice は Doubao、WeChat、その他の入力メソッドを固定しません。

1. **Settings ▸ Voice Input** を開き、ワークフローを有効にします。
2. **入力メソッドの音声ショートカット**を記録します。これは入力メソッド自身の音声機能で使うショートカットです。まず入力メソッド側で設定し、LockIME 自身のショートカットとは別にしてください。
3. **LockIME の音声ショートカット**（**Settings ▸ Shortcuts ▸ Global shortcuts**、または同じ画面）を記録します。実際に押すのはこちらです。
4. 任意：音声入力用の入力メソッドが普段使うものではない場合、**入力ソースを自動で切り替える**をオンにしてその入力メソッドを選びます。先に **Settings ▸ App Rules** でグローバル既定の入力ソースを設定してください。音声入力の終了後にそこへ戻ります。
5. キーボードイベントの送信を求められたら許可します。

LockIME のショートカットを押すと、入力メソッドの音声ショートカットが送信され、現在の入力メソッドで音声入力が始まります。自動切り替えがオンの場合、LockIME は先に設定した音声入力ソースへ切り替え、macOS の確認を待ち、音声入力の終了または安全タイムアウトでグローバル既定の入力ソースへ戻します。

LockIME はそのショートカットを**送信する**だけで、キー入力を監視しません。したがって 2 つのショートカットは別の組み合わせにしてください。同じ組み合わせにすると、1 回の押下が二重に処理され、macOS や入力メソッドがショートカットの競合を通知します。

TextEdit などの通常のテキスト入力欄で確認してください。音声パネルが見えただけでは成功ではありません。認識された文字がカーソル位置に実際に入力される必要があります。
## Comparison

LockIME に対する最も広く使われている代替ツールは **[Input Source Pro](https://github.com/runjuu/InputSourcePro)** と **[KeyboardHolder](https://github.com/leaves615/KeyboardHolder)** の 2 つで、加えてより小規模なオープンソース / CLI ツールが数多く存在します。いずれも、アプリやサイトを移動するたびに入力ソースを*切り替え*ます。LockIME は、入力ソースがずれた瞬間にそれを再適用する継続的な**ロック**を中心に設計されています——しかも、どのルールも一度きりの*切り替え*にフォールバックできます。

| | LockIME | Input Source Pro | KeyboardHolder |
|---|---|---|---|
| 価格 | 無料 | 無料 | 無料（寄付制） |
| オープンソース | GPL-3.0 | GPL-3.0 | ✗（クローズド） |
| 最小 macOS | 14 | 11 | 10.15 |
| ダウンロードサイズ | < 3 MB | ≈ 7.6 MB | ≈ 4.5 MB |
| アプリごとのルール | ✓ | ✓ | ✓ |
| ウェブサイトごと / URL ごとのルール | ✓ | ✓ | ✓ |
| URL マッチタイプ | サブドメイン · 完全一致 · キーワード · 正規表現 | サブドメイン · 完全一致 · 正規表現 | ドメイン（ワイルドカード） |
| アドレスバー（URL フィールド）ルール | ✓（ロック/切り替え/優先順位） | ✓（デフォルトソース） | — |
| 継続的な再ロック | ✓ | ✗ | ✗ |
| ルールごとにロック*または*一度きりの切り替え | ✓ | ✗ | ✗ |
| グローバルキーボードショートカット | ✓ | ✓ | ✗ |
| メニューバーからの操作 | ✓ | ✓ | ✓ |
| 画面上の入力ヒント | ✗ | ✓ | ✓（オプション） |
| 24 時間の作動ログ | ✓ | ✗ | ✗ |
| 設定のバックアップ / インポート | ✓（`.lockime`、確認付き） | ✓（エクスポート/インポート + CLI） | — |
| URL スキーム自動化 | ✓（`lockime-voice://`、x-callback-url） | 部分的（`inputsourcepro://` インポート） | ✗ |
| UI 言語 | 9（ライブ切り替え） | 6 | zh · en · ja |
| システム権限 | コアには不要 · URL ごとには Accessibility | コアには不要 · URL ごとには Accessibility | Accessibility¹ |
| 自動アップデート | ✗（ソースのみのフォーク） | ✓ | ✓ |
| アクティブにメンテナンス中（2026） | ✓ | ✓ | ✓ |

¹ KeyboardHolder はその権限要件を文書化していません。ウェブサイトごとのルールのためにブラウザのアドレスバーを読み取るには、実際には Accessibility 権限が必要です。「—」は確認された非対応ではなく、文書化されていない機能を示します。

**選び方：** Input Source Pro は最大のコミュニティと最も充実した画面上の入力ヒントを備えています。KeyboardHolder は洗練された、ゼロ設定のアプリごとの記憶です。到着したときに切り替わるだけでなく、入力ソースを*固定*したい——アプリごと・URL ごと・アドレスバーで、何かがそれを変更した瞬間に再適用される——なら、LockIME に手を伸ばしてください。

**その他のツール：** [SwitchKey](https://github.com/itsuhane/SwitchKey)（アプリごとのみ、メンテナンス終了）、[Kawa](https://github.com/hatashiro/kawa)（手動、ショートカット駆動）、InputSwitcher（フリーミアム、アプリごとのみ）、そして [macism](https://github.com/laishulu/macism)（コマンドラインの構成要素であり、GUI の切り替えツールではありません）。

> Input Source Pro 2.11.0 と KeyboardHolder 1.14.10 を基準に、2026 年半ばに比較しました——詳細は変動します。訂正を歓迎します。

## Automation

LockIME は `lockime-voice://` URL スキームを公開しており、他のアプリ・スクリプト・ショートカット・ランチャーから操作できます——オン/オフの切り替え、入力ソースの再設定、ルールの管理、そして [x-callback-url](https://x-callback-url.com) コールバックによる状態の読み取りが可能です。デフォルトではオフです——**設定 ▸ 一般 ▸ 自動化**でオンにしてください。

```sh
open "lockime-voice://lock"
open "lockime-voice://lock-to-source?id=com.apple.keylayout.ABC"
open "lockime-voice://set-app-rule?bundle=com.apple.Terminal&mode=lock&source=com.apple.keylayout.ABC"
```

詳細なリファレンス：**[URL Scheme API](../URL-Scheme-API/README.ja.md)**。

## Design

LockIME は単一のデザインシステム（`Sources/LockIME/UI/DesignSystem.swift`）に従います：セマンティックカラー、システムマテリアル、SF Symbols がライト/ダーク適応を担い、Liquid Glass はフローティング/ナビゲーション層だけに使用します。ブランドのアクセントカラー "Lock Indigo" は `AccentColor` アセットとして同梱されています。完全な仕様は [docs/DESIGN.md](../DESIGN.md) を参照してください。

アプリアイコンはプログラムで生成されます（デザインツール不使用）——次のコマンドで再生成できます：

```sh
./scripts/make-appicon.sh   # renders the master via SwiftUI and rebuilds the appiconset
```

## Development

Xcode 26+（アプリ自体のターゲットは macOS 14+）と、[XcodeGen](https://github.com/yonaskolb/XcodeGen) + [xcbeautify](https://github.com/cpisciotta/xcbeautify)（`brew install xcodegen xcbeautify`）が必要です。

```sh
make gen     # generate LockIMEVoice.xcodeproj from project.yml
make build   # build (Debug)
make run     # build & launch
make test    # run unit tests
make archive # ad-hoc-signed Release archive
```

Xcode プロジェクトは `project.yml` から生成され、リポジトリには含まれません。

ハードウェアに触れる統合テスト（実際の TIS 切り替え）は `make test` から除外されています。`make test-hw` で実行してください（入力ソースが一時的に変わります）。

## Releasing

プレビュー DMG は手動でビルドしてアップロードします。Developer ID、公証、Sparkle、nightly、Homebrew は無効のままです。詳細は [docs/RELEASING.md](../RELEASING.md) を参照してください。

## Architecture

- **LockIMEKit**（静的ライブラリ）——システムフレームワークのみを使う、純粋で完全に単体テストされたロジック：ロックエンジン、アプリモニター、ルール、拡張（Accessibility）オブザーバー、ログモデル、ローカリゼーション。
- **LockIME Voice**（アプリ）——`@main`、SwiftUI の UI、デザインシステム、そして Sparkle・KeyboardShortcuts・PermissionFlow 向けの薄い統合シム。

## License

Copyright © 2026 Hangzhou Wumou Software Co., Ltd.

Modifications © 2026 zhangsiqiang519.

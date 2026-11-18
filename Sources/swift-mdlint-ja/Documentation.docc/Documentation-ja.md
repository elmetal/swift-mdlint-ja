# swift-mdlint-ja-jp

## Overview

`swift-mdlint-ja` は、日本語の Markdown 文書に特化したシンプルなリンターです。文章中の句読点の揺れや見出し末尾の記号といったスタイル違反を検出し、可能な場合には自動修正を適用します。Swift 製の CLI として提供されており、ビルド済みバイナリまたは `swift run` から利用できます。

## はじめに

プロジェクトのルートディレクトリで以下を実行して、コマンドラインツールをビルドします。

```bash
swift build -c release
```

ビルド後は `.build/release/mdlint-ja` を PATH に追加するか、`swift run` で直接実行できます。

## 使い方

1 つ以上の Markdown ファイルまたはディレクトリを指定してリンターを実行します。引数を指定しない場合は、カレントディレクトリ以下の `.md` ファイルを再帰的に検査します。ディレクトリを走査するとき、`.build` や `.git` のような隠しファイル・隠しディレクトリは対象外です。コードブロック、インラインコード、HTML は検査と自動修正の対象外です。

```bash
mdlint-ja Docs/README.md
mdlint-ja Articles
```

主なオプションは次のとおりです。

- `--fix` / `-f`: 修正可能な違反に自動修正を適用します。
- `--format <text|gha>`: 出力フォーマットを指定します。`gha` を選ぶと GitHub Actions 形式になります。
- `--strict`: 違反が検出された場合に終了コード `2` で終了します。
- `--config <path>`: 有効化するルール識別子を列挙した JSON ファイルを読み込みます。
- `--politeness-style <auto|desumasu|dearu>`: 敬体・常体の混在チェックで揃える文体を指定します（`auto` は文書内で多い方に合わせます）。

存在しないパスを指定するとエラーとして報告します。残りのパスは通常どおり検査し、終了コード `1` で終了します。

## 設定

設定ファイルはルール識別子の配列を JSON で表現します。未知の識別子が含まれている場合は警告を標準エラーに出力し、該当ルールを無視します。

```json
[
  "ja.period.prefer-fullwidth",
  "ja.heading.no-terminal-punctuation"
]
```

## 出力

違反はファイルパスと行番号を含むメッセージとして出力され、`text` 形式ではルール識別子も表示されます。`--format gha` を使用すると GitHub Actions のワークフローコマンド形式になり、違反が注釈として表示されます。`--fix` を併用した場合はファイルがその場で更新され、修正後も残っている違反だけが報告されます。

## Topics

### English version
- <doc:Documentation>

### ツールの仕組み

- <doc:HowItWorks>

### コマンドオプション

- <doc:FixOption>
- <doc:FormatOption>
- <doc:StrictOption>
- <doc:ConfigOption>

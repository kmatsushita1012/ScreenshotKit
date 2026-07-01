# ScreenshotKit

[English README](README.md)

ScreenshotKit は、SwiftUI アプリから App Store 用スクリーンショットを量産するための Swift Package です。

スクリーンショット用の画面を SwiftUI で定義し、`#Preview` で見た目を詰め、そのまま iPhone / iPad・全ローカライズへ書き出せます。UI Test には依存しません。

## 何ができるか

ScreenshotKit は、スクショ制作を「アプリ本体とは別の作業」ではなく、プロダクトコードの延長として扱いたいときに向いています。

- App Store 用のスクリーンショットを iPhone / iPad 向けにまとめて生成できる
- SwiftUI と `#Preview` で見た目を編集できる
- 本番コードや fixture の変更をすぐスクショに反映できる
- UI Test ベースの重い撮影フローを持たず、軽量に回せる
- ビルド済みアプリの localization を列挙して、対応言語をまとめて出力できる
- manifest ベースで順番に進むので、出力の見通しがよくパイプラインが安定しやすい

実際の出力は、たとえば次のような形になります。

```text
output/
  iPhone 17 Pro Max/
    en-US/
      memo-list.png
      memo-edit.png
    ja-JP/
      memo-list.png
      memo-edit.png
  iPhone 17 Pro Max-manifest.json
  iPad Pro 13-inch (M5)/
    en-US/
      memo-list.png
      memo-edit.png
```

## クイックスタート

### 前提

- iOS 17 以降
- Swift 6
- Xcode 26 以降
- `xcrun`, `xcodebuild`, `python3` が使えること

### 1. パッケージを追加する

Xcode の `Add Package Dependency...` から次を追加します。

```text
https://github.com/kmatsushita1012/ScreenshotKit.git
```

`Package.swift` なら次です。

```swift
dependencies: [
    .package(url: "https://github.com/kmatsushita1012/ScreenshotKit.git", from: "0.1.0")
]
```

### 2. ルート View にスクショ対象を登録する

```swift
import ScreenshotKit
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .screenshot(urlScheme: "myapp") {
                    HomeScreenshot()
                    SettingsScreenshot()
                }
        }
    }
}

struct HomeScreenshot: ScreenshotItem {
    static let id = "home"

    var body: some View {
        ScreenshotView(
            id: Self.id,
            title: "すべてを一箇所で確認",
            subtitle: "進捗・状態・最近の動きをまとめて見せる"
        ) {
            HomeScreen.fixture
        }
        .background(
            LinearGradient(
                colors: [.black, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
```

`ScreenshotView` は、タイトル・サブタイトル・端末フレーム風レイアウトをまとめて扱うベース View です。中身には実画面でも fixture でも画像でも置けます。

### 3. アプリのプロジェクトルートで書き出す

```bash
./scripts/export_screenshots.sh ./output
```

このスクリプトは自動で次を行います。

- カレントディレクトリ配下の最初の `.xcodeproj` を見つける
- scheme と bundle identifier を解決する
- 利用可能な iPhone / iPad Simulator を選ぶ
- アプリを build / install する
- `ProcessInfo` ベースのコマンドでアプリを起動する
- PNG と `manifest.json` を回収する

特定の Simulator だけで回したい場合は、3 引数目に UDID を渡します。

```bash
./scripts/export_screenshots.sh ./output placeholder EBA4AA2F-B463-40A6-B381-C345939380B9
```

## 仕様と応用

### いまの起動フロー

現在ドキュメント化している実行フローは `ProcessInfo` ベースです。

1. export script がアプリを `manifest` モードで起動する
2. ScreenshotKit が登録済み `ScreenshotItem` と localization 一覧を読む
3. `locale × scene` の manifest を作る
4. script が各キャプチャジョブごとにアプリを再起動する
5. ScreenshotKit が指定 scene を描画して readiness を通知する
6. script が Simulator 上の表示結果を PNG として保存する

UI Test を介さず、役割分担がはっきりしているのがこの方式の強みです。

### ローカライズ

ScreenshotKit は、ビルドされたアプリ bundle の localization を列挙します。

- `Base` は無視する
- `ja` は `ja-JP`、`en` は `en-US` のように正規化する
- localization が明示されていなければ development localization、さらに無ければ現在 locale を使う

運用としては次の理解で十分です。

- Xcode 側で対応言語を設定する
- スクショ内の文言も通常どおりローカライズする
- 1 回の export で対応言語をまとめて生成する

`.xcodeproj` は export script 側で自動発見に使われ、そこから app build settings を引き当てます。言語の最終的な列挙は、実際に build された app bundle を正として行われます。

### `ScreenshotItem.id` と出力ファイル名

`ScreenshotItem.id` は、キャプチャジョブ内で scene を識別するための ID です。

`ScreenshotView(id:)` は、最終的な PNG のファイル名に使われます。省略した場合は `001`, `002`, `003` のような連番になります。

```swift
struct DetailScreenshot: ScreenshotItem {
    static let id = "detail"

    var body: some View {
        ScreenshotView(
            title: "詳細をじっくり見せる",
            subtitle: "1 つの操作に集中した訴求ができる"
        ) {
            DetailScreen.fixture
        }
        .background(Color.indigo)
    }
}
```

### 画像ベースの scene

Widget や extension UI のように、通常のアプリ画面として組みにくいものは画像ベースでも扱えます。

```swift
struct AlarmScreenshot: ScreenshotItem {
    static let id = "alarm"

    var body: some View {
        ScreenshotView(
            id: Self.id,
            title: "拡張 UI もそのまま訴求",
            subtitle: "実画面と素材画像を同じ export フローで混ぜられる",
            image: "alarm"
        )
        .background(Color.black)
    }
}
```

### 出力構造

アプリコンテナ内では、セッションごとに次のような構造を管理します。

```text
Application Support/
  ScreenshotKit/
    Sessions/
      latest-session.txt
      session-20260702-120000-000/
        manifest.json
        capture-complete
        iPhone 17 Pro Max/
          en-US/
            home.png
```

その後 export script が最終成果物を指定ディレクトリへコピーし、device ごとに manifest も残します。

### CLI 補足

現在の script のシグネチャは次です。

```bash
./scripts/export_screenshots.sh [output-dir] [legacy-placeholder] [device-id]
```

2 引数目は後方互換のためだけに残っており、現在の `ProcessInfo` ベースフローでは使いません。

### ExampleApp

最小構成のサンプルは [`ExampleApp/`](ExampleApp) に入っています。

- [`ExampleApp/ExampleApp/ExampleApp.swift`](ExampleApp/ExampleApp/ExampleApp.swift)
- [`ExampleApp/ExampleApp/ExampleScreenshotItems.swift`](ExampleApp/ExampleApp/ExampleScreenshotItems.swift)

組み込み方法、Preview ベースの編集感、export の流れを確認する出発点として使えます。

### 注意点

- iOS 専用です
- 現在の API では `.screenshot(urlScheme:)` の引数が残っていますが、現行ドキュメントの実行フローは `ProcessInfo` ベースです
- export script は `.xcodeproj` を見つけられるアプリプロジェクト前提です
- 画像ベース scene を使う場合は対象 asset を app target に含めてください

## License

必要に応じて追加してください。

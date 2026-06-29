# ScreenshotKit

ScreenshotKit は、iOS SwiftUI アプリ内で App Store 用スクリーンショットを一括生成するための Swift Package です。

`simctl screenshot` や UI Test には依存せず、起動中の Simulator 上で実際に描画されている View をアプリ内から PNG として保存します。

## 特徴

- `ProcessInfo` または `openURL(.../screenshots/start)` を 1 回与えるだけで全 locale × 全 scene を自動巡回
- 現在表示されている UIKit view をそのままキャプチャ
- 固定サイズを持たず、起動中デバイスの実サイズ・実 scale を使用
- 出力先は `<session>/<device>/<locale>/<id>.png`
- `manifest.json`、完了マーカー、失敗マーカーを出力
- shell スクリプトで `.xcodeproj` と bundle id を自動推定し、launch trigger で開始
- 通常の View ベース scene に加えて `ScreenshotView(image:)` で asset 画像ベース scene も作成可能

## 動作条件

- iOS 17 以上
- Swift 6
- Xcode 26 系
- macOS 上で `xcrun`, `xcodebuild`, `python3` が利用できること

## インストール

### Swift Package Manager

Xcode の `Add Package Dependency...` から以下を追加します。

```text
https://github.com/kmatsushita1012/ScreenshotKit.git
```

バージョン指定例:

```text
Up to Next Major Version: 0.1.0
```

`Package.swift` で追加する場合:

```swift
dependencies: [
    .package(url: "https://github.com/kmatsushita1012/ScreenshotKit.git", from: "0.1.0")
]
```

## 基本の考え方

ScreenshotKit は 2 つの役割に分かれます。

1. アプリ側
   - スクリーンショット対象 scene を登録する
   - `openURL` または `ProcessInfo` の trigger を受けたら scene を順番に表示して保存する
2. shell 側
   - Simulator を boot する
   - launch trigger を渡してアプリを起動する
   - 完了後に生成物を `./output` などへ回収する

## アプリ側の組み込み

### 1. URL scheme を用意する

ScreenshotKit は `ProcessInfo` または `myapp:/screenshots/start?...` のような URL を受け取って起動します。
Simulator や URL 正規化の都合で `myapp://screenshots/start?...` や `myapp://screenshot/start?...` として届いても受理します。

アプリの `Info.plist` で URL scheme を 1 つ設定してください。

例:

- `myapp`

custom URL trigger を手動で使う場合は、アプリの `Info.plist` に URL scheme を設定してください。

### 2. ルート View に `.screenshot(...)` を付ける

通常のアプリ root に対して `screenshot(urlScheme:items:)` を付与します。

```swift
import ScreenshotKit
import SwiftUI

struct RootView: View {
    var body: some View {
        MainTabView()
            .screenshot(urlScheme: "myapp") {
                HomeScreenshot()
                SettingsScreenshot()
                AlarmScreenshot()
            }
    }
}
```

ここで登録した scene が、全 locale 分だけ順番に実行されます。

### 3. 各 scene を `ScreenshotItem` として定義する

各スクリーンショットは `ScreenshotItem` に準拠した View として定義します。

```swift
import ScreenshotKit
import SwiftUI

struct HomeScreenshot: ScreenshotItem {
    static let id = "home"

    var body: some View {
        ScreenshotView(
            id: "home",
            title: "ホーム",
            subtitle: "すべてを一箇所で管理"
        ) {
            HomeScreen.fixture
        }
        .background(Color.black)
    }
}
```

## `ScreenshotItem.id` と `ScreenshotView.id` の違い

この 2 つは用途が違います。

- `ScreenshotItem.id`
  - scene の内部識別子
  - scene 切り替えやジョブ管理に使う
- `ScreenshotView.id`
  - 保存ファイル名に使う識別子
  - 最終的に `<id>.png` の `id` になる

通常は同じ文字列にしておくと分かりやすいです。

```swift
struct HomeScreenshot: ScreenshotItem {
    static let id = "home"

    var body: some View {
        ScreenshotView(id: "home", title: "ホーム", subtitle: "概要") {
            HomeScreen.fixture
        }
        .background(Color.black)
    }
}
```

### `ScreenshotView.id` を省略した場合

`ScreenshotView.id` を省略した場合は、登録順で `001`, `002`, `003` ... のような 3 桁連番が補完されます。

```swift
struct DetailScreenshot: ScreenshotItem {
    static let id = "detail"

    var body: some View {
        ScreenshotView(
            title: "詳細",
            subtitle: "通知と設定を確認"
        ) {
            DetailScreen.fixture
        }
        .background(Color.blue)
    }
}
```

この場合の保存名は `001.png` や `002.png` のようになります。

## `ScreenshotView`

`ScreenshotView` は App Store 用の見た目を作るためのベース View です。

標準では以下を担当します。

- タイトル
- サブタイトル
- 端末フレーム風のコンテナ
- 中央の content 表示領域

### 通常の content を使う

```swift
ScreenshotView(
    id: "settings",
    title: "設定",
    subtitle: "細かなカスタマイズ"
) {
    SettingsScreen.fixture
}
.background(
    LinearGradient(
        colors: [.indigo, .black],
        startPoint: .top,
        endPoint: .bottom
    )
)
```

### asset 画像を使う

Widget や Alarm extension のように、アプリ本体の通常 View として取り回しづらい UI は `ScreenshotView(image:)` が使えます。

```swift
struct AlarmScreenshot: ScreenshotItem {
    static let id = "alarm"

    var body: some View {
        ScreenshotView(
            id: "alarm",
            title: "アラーム",
            subtitle: "拡張 UI をそのまま訴求",
            image: "alarm"
        )
        .background(Color.black)
    }
}
```

シンプルに画像だけ置きたい場合:

```swift
ScreenshotView(
    id: "widget",
    image: "widget-preview"
)
.background(Color.black)
```

### 背景指定

背景は `ScreenshotView` 専用引数ではなく、通常の SwiftUI の `.background(...)` を使います。

```swift
ScreenshotView(
    id: "home",
    title: "ホーム",
    subtitle: "すべてを一箇所で管理"
) {
    HomeScreen.fixture
}
.background(Color.black)
```

使えるものは通常の `background` と同じです。

- `Color`
- `LinearGradient`
- `Image`
- 独自 View

## locale の扱い

locale は API 引数で渡しません。

ScreenshotKit はアプリ bundle の localizations を元に locale 一覧を自動生成します。

例:

- `ja` -> `ja-JP`
- `en` -> `en-US`

そのため、スクリーンショット対象文字列は通常どおりローカライズしておく必要があります。

各ジョブ実行時、対象 scene には `.environment(\.locale, ...)` が注入されます。

## shell からの実行

リポジトリには `scripts/export_screenshots.sh` が含まれています。

このスクリプトは以下を自動で行います。

- カレントディレクトリ以下の最初の `.xcodeproj` を見つける
- build settings から bundle id を推定する
- 利用可能な最新 iOS runtime を選ぶ
- 利用可能な最上位の iPhone / iPad を 1 台ずつ選ぶ
- Simulator を boot する
- `simctl launch` で ScreenshotKit の autostart 環境変数を渡す
- 完了まで待って生成物を回収する

## ExampleApp

リポジトリには `ExampleApp/` も含まれています。

このアプリは ScreenshotKit の最小組み込みサンプルで、`.screenshot(...)` に複数の `ScreenshotItem` を登録した状態で `ProcessInfo` ベースの capture を検証できます。

構成:

- `ExampleApp/ExampleApp.xcodeproj`
- `ExampleApp/ExampleApp/ExampleApp.swift`
- `ExampleApp/ExampleApp/ContentView.swift`

### ExampleApp での検証コマンド

`device-id` を指定して iPhone 1 台で回す例:

```bash
./scripts/export_screenshots.sh /private/tmp/screenshotkit-example-output placeholder <device-id>
```

このスクリプトは ExampleApp を build / install したあと、`SCREENSHOTKIT_AUTOSTART=1` と `SCREENSHOTKIT_DEVICE_NAME=...` を付けて起動します。

成功すると、たとえば以下のように複数 item の PNG と manifest が回収されます。

```text
/private/tmp/screenshotkit-example-output/
  ScreenShot iPhone/
    en-US/
      welcome.png
      feature.png
      summary.png
  ScreenShot iPhone-manifest.json
```

### 基本コマンド

アプリプロジェクトのルートで実行します。

```bash
./scripts/export_screenshots.sh
```

デフォルト出力先:

```text
./output
```

### 引数

```bash
./scripts/export_screenshots.sh [output-dir] [url-scheme] [device-id]
```

- `output-dir`
  - 生成物のコピー先
  - 省略時は `./output`
- `url-scheme`
  - 後方互換のため受け取るだけで、現行スクリプトでは未使用
- `device-id`
  - 特定の Simulator UDID だけで回したい場合に指定
  - 省略時は iPhone / iPad の両方を実行

### 実行例

出力先だけ指定:

```bash
./scripts/export_screenshots.sh ./artifacts
```

URL scheme を手動指定:

```bash
./scripts/export_screenshots.sh ./artifacts myapp
```

特定デバイスだけ指定:

```bash
./scripts/export_screenshots.sh ./artifacts myapp EBA4AA2F-B463-40A6-B381-C345939380B9
```

## アプリ内で何が起きるか

`SCREENSHOTKIT_AUTOSTART=1` と `SCREENSHOTKIT_DEVICE_NAME=...`、または `myapp:/screenshots/start?deviceName=...` を受けると、アプリ内では次の順で処理します。

1. `deviceName` を `ProcessInfo` または URL から取得
2. セッションディレクトリを作成
3. bundle の locale 一覧を取得
4. `locale × scene` のジョブ列を作成
5. scene を 1 件表示
6. 表示済み View の `id` を確定
7. 表示されている UIKit view を PNG として保存
8. 次の scene へ進む
9. 全件完了後に `manifest.json` と `capture-complete` を書き出す

進行は直列です。並列で scene を保存しません。

## 出力構造

アプリ sandbox 内には以下の構造で保存されます。

```text
Application Support/
  ScreenshotKit/
    Sessions/
      latest-session.txt
      session-20260627-123456-789/
        session.txt
        manifest.json
        capture-complete
        iPhone 17 Pro Max/
          ja-JP/
            home.png
            settings.png
        iPad Pro 13-inch (M5)/
          ja-JP/
            home.png
            settings.png
```

shell スクリプトはこのセッションから、最終的に以下のように回収します。

```text
./output/
  iPhone 17 Pro Max/
    ja-JP/
      home.png
  iPhone 17 Pro Max-manifest.json
  iPad Pro 13-inch (M5)/
    ja-JP/
      home.png
  iPad Pro 13-inch (M5)-manifest.json
```

## `manifest.json`

`manifest.json` には少なくとも以下の情報が含まれます。

- device 名
- session path
- completedAt
- 各画像の scene ID
- locale
- output identifier
- relative path

生成物の後処理やアップロード前チェックに使えます。

## 失敗時

キャプチャに失敗した場合は、セッションディレクトリに以下が出力されます。

```text
capture-error.txt
```

shell スクリプト実行時は、その内容を stderr に出して終了します。

## よくある使い分け

### 1. 画面そのものを撮りたい

通常の View を `content` に渡します。

```swift
ScreenshotView(id: "home", title: "ホーム", subtitle: "概要") {
    HomeScreen.fixture
}
.background(Color.black)
```

### 2. 実画面の取得が難しい

asset 画像を使います。

```swift
ScreenshotView(id: "alarm", image: "alarm")
    .background(Color.black)
```

### 3. locale ごとに自動で出したい

アプリの localizations を設定しておくだけです。

ScreenshotKit 側で locale 一覧を自動巡回します。

## 注意点

- iOS 専用です
- scene 進行は外部から `next` しません
- `simctl screenshot` は使いません
- shell スクリプトは `.xcodeproj` が存在するアプリプロジェクトで動かしてください
- custom URL trigger を使う場合は `Info.plist` の URL scheme 設定が必要です
- asset 画像を使う場合は、対象 asset がアプリ側 bundle に含まれている必要があります

## 最小構成サンプル

```swift
import ScreenshotKit
import SwiftUI

struct MarketingShot: ScreenshotItem {
    static let id = "marketing-home"

    var body: some View {
        ScreenshotView(
            id: "home",
            title: "ホーム",
            subtitle: "毎日の状態をすばやく確認"
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

struct AssetBasedShot: ScreenshotItem {
    static let id = "alarm-shot"

    var body: some View {
        ScreenshotView(
            id: "alarm",
            title: "アラーム",
            subtitle: "拡張 UI をそのまま紹介",
            image: "alarm"
        )
        .background(Color.black)
    }
}

struct RootView: View {
    var body: some View {
        AppContentView()
            .screenshot(urlScheme: "myapp") {
                MarketingShot()
                AssetBasedShot()
            }
    }
}
```

実行:

```bash
./scripts/export_screenshots.sh
```

## ライセンス

必要に応じて追加してください。

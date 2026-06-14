# SwiftUI Screenshot Generator 仕様書

## 1. 概要

本システムは SwiftUI アプリ向けの App Store スクリーンショット自動生成システムである。

UI Test や環境変数は使用せず、Shell Script と `simctl openurl` / `simctl screenshot` により、スクリーンショット対象 View の表示切替と撮影を行う。

---

# 2. 基本方針

- UI Test は使用しない
- 環境変数は使用しない
- Root View の `if` 分岐は使用しない
- スクリーンショット制御は URL Scheme で行う
- Screenshot View は ResultBuilder で登録する
- App 側がスクショ一覧・ファイル名・終了判定を持つ
- Shell 側はシーン数を知らない
- 画像保存は `xcrun simctl io booted screenshot` で行う

---

# 3. 最終 API

```swift
AppRootView()
    .screenshot {
        MyHomeScreenshot()
        MyDetailScreenshot()
        PremiumScreenshot()
    }
```

---

# 4. Screenshot Item

スクリーンショット 1 枚分は独立した `ScreenshotItem` として定義する。

```swift
protocol ScreenshotItem: View {
    static var id: String { get }
    static var filename: String { get }
}
```

例:

```swift
struct MyHomeScreenshot: ScreenshotItem {
    static let id = "home"
    static let filename = "01_home"

    var body: some View {
        ScreenshotView(
            title: "ホーム",
            subtitle: "すべてを一箇所で管理"
        ) {
            MyHomeContent(fixture: .home)
        }
        .background {
            LinearGradient(...)
        }
    }
}
```

---

# 5. Screenshot Registration

`RootView` に `.screenshot {}` をアタッチして、撮影対象 View を登録する。

```swift
AppRootView()
    .screenshot {
        MyHomeScreenshot()
        MyDetailScreenshot()
        PremiumScreenshot()
    }
```

登録順が撮影順になる。

---

# 6. Screenshot Host

`.screenshot {}` Modifier は、通常時は元の `AppRootView` を表示する。

URL Scheme で `screenshot/start` を受け取った場合のみ、内部的に Screenshot Host を表示する。

Root View 側で以下のような分岐は書かない。

```swift
// 不要
if isScreenshotMode {
    ScreenshotRootView()
} else {
    AppRootView()
}
```

切り替え責務は `.screenshot {}` Modifier が持つ。

---

# 7. URL Scheme

## 7.1 開始

```bash
xcrun simctl openurl booted "myapp://screenshot/start"
```

この URL を受け取ると、Screenshot Host を表示し、最初の Screenshot Item を表示する。

## 7.2 次へ

```bash
xcrun simctl openurl booted "myapp://screenshot/next"
```

次の Screenshot Item に切り替える。

最後の Item の次へ進もうとした場合は、終了状態にする。

---

# 8. State File

App は現在のスクリーンショット状態を `Application Support/screenshot_state.json` に書き出す。

```json
{
  "id": "home",
  "filename": "01_home",
  "finished": false
}
```

終了時:

```json
{
  "finished": true
}
```

---

# 9. Shell 側の State File 取得

Shell は `simctl get_app_container` で App の Data Container を取得する。

```bash
APP_CONTAINER=$(
  xcrun simctl get_app_container booted com.example.app data
)

STATE_FILE="$APP_CONTAINER/Library/Application Support/screenshot_state.json"
```

---

# 10. Screenshot 撮影

画像保存は Shell 側で行う。

```bash
xcrun simctl io booted screenshot "Screenshots/01_home.png"
```

Swift 側では画像保存しない。

---

# 11. Shell Script

```bash
#!/bin/bash

set -e

BUNDLE_ID="com.example.app"
URL_SCHEME="myapp"
OUT_DIR="./Screenshots"

mkdir -p "$OUT_DIR"

APP_CONTAINER=$(
  xcrun simctl get_app_container booted "$BUNDLE_ID" data
)

STATE_FILE="$APP_CONTAINER/Library/Application Support/screenshot_state.json"

xcrun simctl openurl booted "$URL_SCHEME://screenshot/start"

sleep 1

while true
do
  finished=$(jq -r '.finished' "$STATE_FILE")

  if [ "$finished" = "true" ]; then
    echo "Screenshot finished"
    break
  fi

  filename=$(jq -r '.filename' "$STATE_FILE")

  xcrun simctl io booted screenshot "$OUT_DIR/${filename}.png"

  xcrun simctl openurl booted "$URL_SCHEME://screenshot/next"

  sleep 1
done
```

---

# 12. ScreenshotView

`ScreenshotView` は App Store 用レイアウトを提供する。

```swift
ScreenshotView(
    title: "タイトル",
    subtitle: "サブタイトル"
) {
    ContentView()
}
```

管理対象:

- title
- subtitle
- background
- overlay
- content
- safe area
- scale

---

# 13. 責務分離

| 領域 | 責務 |
|---|---|
| App | Screenshot View 登録 |
| App | 現在の Screenshot Item 管理 |
| App | filename / finished の書き出し |
| Shell | start / next の送信 |
| Shell | state JSON 読み取り |
| Shell | PNG 保存 |
| simctl | URL Scheme 実行・スクショ撮影 |

---

# 14. メリット

- UI Test 不要
- 環境変数不要
- Root View の分岐不要
- Shell 側にシーン定義不要
- SwiftUI らしい宣言的 API
- 1 Screenshot = 1 View 型で管理できる
- Preview しやすい
- CI/CD に組み込みやすい

---

# 15. 最終形

```swift
AppRootView()
    .screenshot {
        MyHomeScreenshot()
        MyDetailScreenshot()
        PremiumScreenshot()
    }
```

```bash
xcrun simctl openurl booted "myapp://screenshot/start"
xcrun simctl io booted screenshot "./Screenshots/01_home.png"
xcrun simctl openurl booted "myapp://screenshot/next"
```
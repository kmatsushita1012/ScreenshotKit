# ScreenshotKit 仕様書

## 概要

ScreenshotKit は iOS SwiftUI アプリ内で App Store 用スクリーンショットを一括生成する。
Shell は Xcode プロジェクト情報を推定し、iPhone / iPad Simulator を boot したうえで launch trigger を付けてアプリを起動する。実際のキャプチャと保存はアプリ内で完結させる。

## 基本方針

- UI Test は使わない
- `simctl screenshot` は使わない
- `ProcessInfo` を受けたら全 locale × 全 scene を自動巡回する
- キャプチャは現在表示中の UIKit view をそのまま PNG 化する
- サイズは固定値を持たず、起動中デバイスの実描画サイズを使う
- locale 一覧は `Bundle` の localizations を正とする
- 保存先構造は `<session>/<deviceName>/<locale>/<id>.png`

## 公開 API

```swift
AppRootView()
    .screenshot {
        HomeScreenshot()
        DetailScreenshot()
    }
```

```swift
public protocol ScreenshotItem: View, Sendable {
    static var id: String { get }
}
```

```swift
ScreenshotView(
    id: "home",
    title: "ホーム",
    subtitle: "すべてを一箇所で管理"
) {
    HomeContentView()
}
.background(Color.black)

ScreenshotView(
    id: "alarm",
    title: "アラーム",
    subtitle: "拡張 UI をそのまま訴求",
    image: "alarm"
)
.background(
    LinearGradient(
        colors: [.black, .blue],
        startPoint: .top,
        endPoint: .bottom
    )
)
```

- `ScreenshotItem.id`
  - scene の内部識別子
- `ScreenshotView.id`
  - 保存ファイル名に使う識別子
  - 省略時は `001`, `002`, ... を自動採番する
- `ScreenshotView(image:)`
  - `content` の代わりに app asset の画像を phone frame 内へ表示する
  - widget や alarm extension など View 取得が難しい UI の代替に使う
- 背景
  - `ScreenshotView` 専用引数は使わず、通常の `.background(...)` で指定する

## 起動フロー

Shell から以下のように起動する。

```bash
SIMCTL_CHILD_SCREENSHOTKIT_AUTOSTART=1 \
SIMCTL_CHILD_SCREENSHOTKIT_DEVICE_NAME="iPhone 17 Pro Max" \
xcrun simctl launch --terminate-running-process <udid> <bundle-id>
```

アプリ側の動作:

1. `deviceName` を `ProcessInfo` から取り出す
2. `Bundle` から locale 一覧を取得する
3. `locale × scene` のジョブ列を作る
4. 1件ずつ表示する
5. 描画済み View そのものを保存する
6. 全件完了後に完了マーカーを書き出す

## 保存仕様

- セッションルートは `Application Support/ScreenshotKit/Sessions/session-<timestamp>/`
- 画像保存先は `<session>/<deviceName>/<locale>/<id>.png`
- 完了時は `<session>/capture-complete`
- 失敗時は `<session>/capture-error.txt`
- 完了時は `<session>/manifest.json`
- 最新セッション参照用に `Application Support/ScreenshotKit/Sessions/latest-session.txt` を更新する

## Shell の責務

- `.xcodeproj` から bundle ID を推定する
- 利用可能な最新 iOS runtime を選ぶ
- `device-id` が指定されたらその Simulator だけを boot して実行する
- `device-id` が省略されたら iPhone / iPad の上位機種を 1 台ずつ boot する
- 各 Simulator に対して launch trigger 付きでアプリを起動する
- `latest-session.txt` と `capture-complete` を見て完了を待つ
- 完成済みセッションから `<deviceName>/` 以下をユーザー指定先、未指定時は `./output` にコピーする
- `manifest.json` も回収する

Shell は以下を持たない。

- scene 数の知識
- locale 数の知識
- 画像撮影責務
- `next` の送信責務
- JSON 状態読み取り責務

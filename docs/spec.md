# ScreenshotKit 仕様書

## 概要

ScreenshotKit は iOS SwiftUI アプリ内で App Store 用スクリーンショットを一括生成する。
Shell は `simctl openurl` で `screenshot/start` を 1 回送るだけとし、実際のキャプチャと保存はアプリ内で完結させる。

## 基本方針

- UI Test は使わない
- `simctl screenshot` は使わない
- `screenshot/start` を受けたら全 locale × 全 scene を自動巡回する
- キャプチャは現在表示中の UIKit view をそのまま PNG 化する
- サイズは固定値を持たず、起動中デバイスの実描画サイズを使う
- locale 一覧は `Bundle` の localizations を正とする
- 保存先構造は `<session>/<deviceName>/<locale>/<id>.png`

## 公開 API

```swift
AppRootView()
    .screenshot(urlScheme: "myapp") {
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
```

- `ScreenshotItem.id`
  - scene の内部識別子
- `ScreenshotView.id`
  - 保存ファイル名に使う識別子
  - 省略時は `001`, `002`, ... を自動採番する

## 起動フロー

Shell から以下を送る。

```bash
xcrun simctl openurl booted "myapp://screenshot/start?deviceName=iPhone%2016%20Pro"
```

アプリ側の動作:

1. `deviceName` を取り出す
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

- `screenshot/start` を 1 回送る
- `latest-session.txt` と `capture-complete` を見て完了を待つ
- 完成済みセッションから `<deviceName>/` 以下をユーザー指定先、未指定時は `./output` にコピーする

Shell は以下を持たない。

- scene 数の知識
- locale 数の知識
- 画像撮影責務
- `next` の送信責務
- JSON 状態読み取り責務

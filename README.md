# ScreenshotKit

[日本語版はこちら](README_ja.md)

ScreenshotKit is a Swift Package for generating App Store screenshots from a SwiftUI app with a lightweight simulator-driven pipeline.

You define screenshot scenes in SwiftUI, preview them locally, and export every scene across every supported localization without UI tests.

## What You Can Create

ScreenshotKit is built for teams that want App Store screenshots to live next to product code instead of a separate design-time pipeline.

- Generate App Store screenshots for iPhone and iPad from the same app project
- Edit layouts in SwiftUI and iterate visually with `#Preview`
- Reflect production UI changes immediately by rendering real app views or fixture-backed screens
- Avoid a UI-test-driven capture flow and keep the export path lightweight
- Export all supported localizations automatically from the built app bundle
- Keep the pipeline predictable with a manifest-first flow and file-based outputs

In practice, one export run produces a structure like this:

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

## Quick Start

### Requirements

- iOS 17 or later
- Swift 6
- Xcode 26 or later
- `xcrun`, `xcodebuild`, and `python3`

### 1. Add the package

Add ScreenshotKit in Xcode with `Add Package Dependency...`:

```text
https://github.com/kmatsushita1012/ScreenshotKit.git
```

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/kmatsushita1012/ScreenshotKit.git", from: "0.1.0")
]
```

### 2. Register screenshot scenes in your root view

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
            title: "Everything in one place",
            subtitle: "Review progress, status, and recent activity at a glance"
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

`ScreenshotView` is the marketing layout container. The content inside it can be a real screen, a fixture-backed screen, or an image-based scene.

### 3. Run the exporter from your app project

```bash
./scripts/export_screenshots.sh ./output
```

The script automatically:

- finds the first `.xcodeproj` under the current directory
- resolves the app scheme and bundle identifier
- picks available iPhone and iPad simulators
- builds and installs the app
- launches the app with `ProcessInfo`-based screenshot commands
- collects PNG files and `manifest.json`

If you want to target a specific simulator, pass its UDID as the third argument:

```bash
./scripts/export_screenshots.sh ./output placeholder EBA4AA2F-B463-40A6-B381-C345939380B9
```

## Detailed Behavior And Advanced Usage

### How the pipeline works

The current documented flow is `ProcessInfo`-based.

1. The export script launches the app in `manifest` mode.
2. ScreenshotKit reads registered `ScreenshotItem`s and bundle localizations.
3. A manifest is written for `locale × scene`.
4. The script relaunches the app for each capture job.
5. ScreenshotKit renders the requested scene and publishes readiness.
6. The script captures the simulator output and stores the final PNG.

This keeps the orchestration explicit and avoids a UI test layer.

### Localization behavior

ScreenshotKit enumerates localizations from the built app bundle.

- `Base` is ignored
- simple language codes are normalized such as `ja -> ja-JP` and `en -> en-US`
- if no explicit localization exists, the development localization or current locale is used

That means the practical workflow is:

- define app localizations in Xcode
- localize your screenshot strings normally
- export once and let ScreenshotKit generate every supported locale

### `ScreenshotItem.id` and output names

`ScreenshotItem.id` identifies the scene in the capture pipeline.

`ScreenshotView(id:)` controls the output file name. If you omit it, ScreenshotKit falls back to a zero-padded sequence such as `001`, `002`, and `003`.

```swift
struct DetailScreenshot: ScreenshotItem {
    static let id = "detail"

    var body: some View {
        ScreenshotView(
            title: "Detail",
            subtitle: "Focus on one workflow at a time"
        ) {
            DetailScreen.fixture
        }
        .background(Color.indigo)
    }
}
```

### Using image-based scenes

For surfaces that are hard to reconstruct as a regular app screen, such as widgets or extension UIs, you can use image-based scenes.

```swift
struct AlarmScreenshot: ScreenshotItem {
    static let id = "alarm"

    var body: some View {
        ScreenshotView(
            id: Self.id,
            title: "Promote extension UI directly",
            subtitle: "Mix app screens and prepared assets in one export flow",
            image: "alarm"
        )
        .background(Color.black)
    }
}
```

### Output structure

Inside the app container, ScreenshotKit manages a session directory like this:

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

The export script then copies the final outputs into your target directory and keeps one manifest per device.

### CLI notes

The current script signature is:

```bash
./scripts/export_screenshots.sh [output-dir] [legacy-placeholder] [device-id]
```

The second argument is kept only for backward compatibility and is ignored by the current `ProcessInfo`-based flow.

### Example app

[`ExampleApp/`](ExampleApp) shows the minimal integration:

- [`ExampleApp/ExampleApp/ExampleApp.swift`](ExampleApp/ExampleApp/ExampleApp.swift)
- [`ExampleApp/ExampleApp/ExampleScreenshotItems.swift`](ExampleApp/ExampleApp/ExampleScreenshotItems.swift)

Use it to confirm the package setup, Preview-based editing, and end-to-end export behavior.

### Limitations

- iOS only
- the root modifier still requires `urlScheme:` in the current API surface, even though the documented execution flow is `ProcessInfo`-based
- the export script expects an app project with a discoverable `.xcodeproj`
- image-based scenes require the asset to be bundled in the app target

## License

Add your preferred license here.

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
- Generate every screenshot case from the scenes you define in code and the languages configured in your `.xcodeproj`
- Keep screenshot production inside the app project instead of maintaining a separate capture matrix

![ScreenshotKit workflow](docs/images/readme-preview-workflow.png)

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
    .package(url: "https://github.com/kmatsushita1012/ScreenshotKit.git", from: "1.1.0")
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
                .screenshot {
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
            title: "Everything in one place",
            subtitle: "Review progress, status, and recent activity at a glance"
        ) {
            HomeContentView(item: .fixture)
        }
        .background(Color(red: 0.93, green: 0.96, blue: 1.0))
    }
}
```

### 3. Run the exporter

From this package repository:

```bash
swift run screenshotkit-export --project ExampleApp/ExampleApp.xcodeproj --output-dir ./output
```

When exporting another app, point `--project` at that app's `.xcodeproj`.

## Specification

### Capture flow

1. The executable launches the app in `manifest` mode.
2. ScreenshotKit reads registered `ScreenshotItem`s and bundle localizations.
3. A manifest is written for `locale × scene`.
4. The executable relaunches the app for each capture job.
5. ScreenshotKit renders the requested scene and publishes readiness.
6. The executable captures the simulator output and stores the final PNG.

This keeps the orchestration explicit and avoids a UI test layer.

### Localization behavior

ScreenshotKit reads the localizations included in the built app bundle, so the export set is effectively driven by the screenshot scenes you define in code and the languages configured in your `.xcodeproj`.

- `Base` is ignored
- simple language codes are normalized such as `ja -> ja-JP` and `en -> en-US`
- if no explicit localization exists, the development localization or current locale is used

That means the practical workflow is:

- define app localizations in Xcode
- localize your screenshot strings normally
- export once and let ScreenshotKit generate every supported locale

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

The executable then copies the final outputs into your target directory and keeps one manifest per device.

### Limitations

- iOS only
- the executable expects an app project with a discoverable `.xcodeproj`
- image-based scenes require the asset to be bundled in the app target

## Advanced Usage

### `ScreenshotItem.id` and output names

`ScreenshotItem.id` is the single identifier for each screenshot scene.

The same value is used for scene selection, manifest entries, and output file names such as `detail.png`.

```swift
struct DetailScreenshot: ScreenshotItem {
    static let id = "detail"

    var body: some View {
        ScreenshotView(
            title: "Detail",
            subtitle: "Focus on one workflow at a time"
        ) {
            DetailContentView(item: .fixture)
        }
        .background(Color.indigo)
    }
}
```

### `ScreenshotView`

`ScreenshotView` supports two scene shapes:

- pass a SwiftUI view with a trailing closure
- pass prepared image assets with `ScreenshotImage`

```swift
struct HomeScreenshot: ScreenshotItem {
    static let id = "home"

    var body: some View {
        ScreenshotView(
            title: "Everything in one place",
            subtitle: "Review progress, status, and recent activity at a glance"
        ) {
            HomeContentView(item: .fixture)
        }
        .background(Color(red: 0.93, green: 0.96, blue: 1.0))
    }
}
```

```swift
struct PromoScreenshot: ScreenshotItem {
    static let id = "promo"

    var body: some View {
        ScreenshotView(
            title: "Show every device at its best",
            subtitle: "Use separate prepared artwork for iPhone and iPad",
            image: .init(phone: "PromoPhone", pad: "PromoPad")
        )
        .background(Color(red: 0.95, green: 0.95, blue: 0.98))
    }
}
```

`ScreenshotImage` selects the asset that matches the current device kind.

### Using image-based scenes

For surfaces that are hard to reconstruct as a regular app screen, such as widgets or extension UIs, you can use image-based scenes.

```swift
struct AlarmScreenshot: ScreenshotItem {
    static let id = "alarm"

    var body: some View {
        ScreenshotView(
            title: "Promote extension UI directly",
            subtitle: "Mix app screens and prepared assets in one export flow",
            image: .init(phone: "AlarmPhone", pad: "AlarmPad")
        )
        .background(Color(red: 0.95, green: 0.95, blue: 0.98))
    }
}
```

If the same asset is valid for both device kinds, pass the same name twice.

### Export executable

The exporter supports positional arguments and named options:

```bash
swift run screenshotkit-export [output-dir] [device-id]
swift run screenshotkit-export --output-dir ./output --device-id <simulator-udid>
swift run screenshotkit-export --project path/to/App.xcodeproj
```

The executable discovers a usable app project, picks flagship iPhone and iPad simulators from the latest available iOS runtime, launches each locale declared by the app bundle, and writes one manifest per device into the output directory.

### Example app

[`ExampleApp/`](ExampleApp) shows the minimal integration:

- [`ExampleApp/ExampleApp/ExampleApp.swift`](ExampleApp/ExampleApp/ExampleApp.swift)
- [`ExampleApp/ExampleApp/ExampleScreenshotItems.swift`](ExampleApp/ExampleApp/ExampleScreenshotItems.swift)

Use it to confirm the package setup, Preview-based editing, and end-to-end export behavior.

## License

MIT. See [LICENSE](LICENSE).

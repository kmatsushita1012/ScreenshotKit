import ScreenshotKit
import SwiftUI

@main
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ExampleRootView()
                .screenshot(urlScheme: "exampleapp") {
                    WelcomeScreenshot()
                    FeatureScreenshot()
                    SummaryScreenshot()
                }
        }
    }
}

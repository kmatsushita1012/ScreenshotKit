import ScreenshotKit
import SwiftUI

@main
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ExampleAppView()
                .screenshot {
                    MemoListScreenshot()
                    MemoEditScreenshot()
                }
        }
    }
}

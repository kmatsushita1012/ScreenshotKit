import ScreenshotKit
import SwiftUI

struct MemoListScreenshot: ScreenshotItem {
    static let id = "memo-list"
    @Environment(\.locale) private var locale

    var body: some View {
        ScreenshotView(
            title: ExampleAppStrings.localized("screenshot.memoList.title", locale: locale),
            subtitle: ExampleAppStrings.localized("screenshot.memoList.subtitle", locale: locale)
        ) {
            MemoListView(memos: Memo.screenshotList)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.98, blue: 1.0),
                    Color(red: 0.89, green: 0.95, blue: 1.0),
                    Color(red: 0.93, green: 0.98, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

#Preview {
    MemoListScreenshot()
}

struct MemoEditScreenshot: ScreenshotItem {
    static let id = "memo-edit"
    @Environment(\.locale) private var locale

    var body: some View {
        ScreenshotView(
            title: ExampleAppStrings.localized("screenshot.memoEdit.title", locale: locale),
            subtitle: ExampleAppStrings.localized("screenshot.memoEdit.subtitle", locale: locale)
        ) {
            MemoEditView(memo: Memo.screenshotDraft)
        }
        .background(
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.96, blue: 0.9),
                    Color(red: 0.99, green: 0.91, blue: 0.82),
                    Color(red: 0.95, green: 0.87, blue: 0.95)
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 520
            )
        )
    }
}


#Preview {
    MemoEditScreenshot()
}

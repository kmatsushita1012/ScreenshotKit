import ScreenshotKit
import SwiftUI

struct MemoListScreenshot: ScreenshotItem {
    static let id = "memo-list"

    var body: some View {
        ScreenshotView(
            title: "Stay on top of every note",
            subtitle: "Pinned memos, recent updates, and quick context at a glance"
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

    var body: some View {
        ScreenshotView(
            title: "Edit without losing focus",
            subtitle: "Title, category, and content stay together in one calm workspace"
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

struct MemoPreviewScreenshot: ScreenshotItem {
    static let id = "memo-preview"

    var body: some View {
        ScreenshotView(
            title: "Show every device at its best",
            subtitle: "Reuse one screenshot item while tailoring prepared artwork for iPhone and iPad",
            image: .init(phone: "MemoPreviewPhone", pad: "MemoPreviewPad")
        )
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.81, green: 0.93, blue: 0.97),
                    Color(red: 0.02, green: 0.78, blue: 0.76),
                    Color(red: 0.05, green: 0.25, blue: 0.64)
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        )
    }
}


#Preview {
    MemoPreviewScreenshot()
}

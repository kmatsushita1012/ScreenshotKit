import ScreenshotKit
import SwiftUI

struct ExampleAppView: View {
    @State private var isShowingScreenshotView = false

    var body: some View {
        NavigationStack {
            List {
                Section("Capture") {
                    Button {
                        isShowingScreenshotView = true
                    } label: {
                        Label("ScreenshotView を開く", systemImage: "iphone.gen3")
                    }
                    .buttonStyle(.plain)
                    .fullScreenCover(isPresented: $isShowingScreenshotView) {
                        ScreenshotView(
                            title: "Welcome",
                            subtitle: "ScreenshotView sample"
                        ) {
                            screenshotPreviewContent
                        }
                    }
                    Label("ProcessInfo から自動開始", systemImage: "play.circle.fill")
                    Label("複数シーンを順番に保存", systemImage: "square.stack.3d.up.fill")
                    Label("完了時に capture-complete を出力", systemImage: "checkmark.seal.fill")
                }

                Section("Verification") {
                    LabeledContent("Launch mode", value: "ProcessInfo")
                    LabeledContent("Example target", value: "Screen-based UI")
                    LabeledContent("Output", value: "Ignored .build directory")
                }
            }
            .navigationTitle("ScreenshotKit")
        }
    }
}

private extension ExampleAppView {
    var screenshotPreviewContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Open from normal launch")
                    .font(.title2.weight(.semibold))
                Text("Double tap anywhere to dismiss this full screen preview.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(Color(red: 0.95, green: 0.97, blue: 1.0))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            isShowingScreenshotView = false
        }
    }
}

#Preview {
    ExampleAppView()
}

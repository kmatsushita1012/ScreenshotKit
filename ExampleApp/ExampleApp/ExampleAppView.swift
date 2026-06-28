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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Dummy", systemImage: "xmark"){
                        print("dummy")
                    }
                }
            }
        }
    }
}

private extension ExampleAppView {
    var screenshotPreviewContent: some View {
        ScrollView {
            ForEach(0..<10) { _ in
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.blue)
        .onTapGesture(count: 2) {
            isShowingScreenshotView = false
        }
        .navigationTitle("Hello")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Dummy", systemImage: "checkmark"){
                    print("dummy")
                }
            }
        }
    }
}

#Preview {
    ExampleAppView()
}

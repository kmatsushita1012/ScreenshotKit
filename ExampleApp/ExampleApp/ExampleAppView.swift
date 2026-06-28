import ScreenshotKit
import SwiftUI
import ScreenshotKit

struct ExampleAppView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Capture") {
                    NavigationLink {
                        ScreenshotView(
                            title: "Welcome",
                            subtitle: "ScreenshotView sample"
                        ) {
                            VStack(spacing: 24) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 52, weight: .semibold))
                                    .foregroundStyle(.blue)

                                VStack(spacing: 8) {
                                    Text("Open from normal launch")
                                        .font(.title2.weight(.semibold))
                                    Text("Use this route to inspect ScreenshotView and the navigation bar interactively.")
                                        .font(.body)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(32)
                            .background(Color(red: 0.95, green: 0.97, blue: 1.0))
                        }
                    } label: {
                        Label("ScreenshotView を開く", systemImage: "iphone.gen3")
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

#Preview {
    ExampleAppView()
}

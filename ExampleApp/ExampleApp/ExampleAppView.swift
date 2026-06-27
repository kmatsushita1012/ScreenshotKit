import SwiftUI

struct ExampleAppView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Capture") {
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

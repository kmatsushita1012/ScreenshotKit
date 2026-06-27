import ScreenshotKit
import SwiftUI

struct ExampleRootView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("ScreenshotKit Example")
                    .font(.largeTitle.bold())
                Text("ProcessInfo trigger validation app")
                    .foregroundStyle(.secondary)
                Image(systemName: "camera.on.rectangle")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [.white, Color.blue.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

struct WelcomeScreenshot: ScreenshotItem {
    static let id = "welcome"

    var body: some View {
        ScreenshotView(
            id: "welcome",
            title: "Welcome",
            subtitle: "ProcessInfo triggered capture"
        ) {
            ScreenshotCard(
                icon: "sparkles",
                title: "Launch Autostart",
                message: "The first item verifies session creation."
            )
        }
        .background(Color(red: 0.95, green: 0.97, blue: 1.0))
    }
}

struct FeatureScreenshot: ScreenshotItem {
    static let id = "feature"

    var body: some View {
        ScreenshotView(
            id: "feature",
            title: "Multiple Items",
            subtitle: "Advances through more than one scene"
        ) {
            ScreenshotChecklist(
                items: [
                    "ProcessInfo autostart works",
                    "Second item renders",
                    "Capture continues serially"
                ]
            )
        }
        .background(Color(red: 0.93, green: 0.98, blue: 0.95))
    }
}

struct SummaryScreenshot: ScreenshotItem {
    static let id = "summary"

    var body: some View {
        ScreenshotView(
            id: "summary",
            title: "Completion",
            subtitle: "Writes capture-complete when all scenes finish"
        ) {
            ScreenshotCard(
                icon: "checkmark.seal.fill",
                title: "Done",
                message: "The final item proves the run reaches completion."
            )
        }
        .background(Color(red: 1.0, green: 0.96, blue: 0.92))
    }
}

private struct ScreenshotCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text(title)
                .font(.title.bold())

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
        )
        .padding(28)
    }
}

private struct ScreenshotChecklist: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(item)
                        .font(.headline)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
        )
        .padding(28)
    }
}

#Preview {
    ExampleRootView()
}

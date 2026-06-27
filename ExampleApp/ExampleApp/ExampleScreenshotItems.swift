import ScreenshotKit
import SwiftUI

struct WelcomeScreenshot: ScreenshotItem {
    static let id = "welcome"

    var body: some View {
        ScreenshotView(
            id: "welcome",
            title: "Welcome",
            subtitle: "ProcessInfo triggered capture"
        ) {
            ExampleScreen(
                eyebrow: "AUTOSTART",
                title: "Start from ProcessInfo",
                subtitle: "The first scene verifies the launch path without needing openURL.",
                accent: .blue,
                body: {
                    VStack(alignment: .leading, spacing: 16) {
                        ScreenStatusRow(
                            icon: "sparkles",
                            title: "Launch detected",
                            detail: "ExampleApp boots directly into screenshot mode."
                        )
                        ScreenStatusRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Scene ready",
                            detail: "Each item renders as a full screen, not a card."
                        )
                    }
                }
            )
        }
        .background(Color(red: 0.95, green: 0.97, blue: 1.0))
    }
}

＃Preview {
    WelcomeScreenshot()
}

struct FeatureScreenshot: ScreenshotItem {
    static let id = "feature"

    var body: some View {
        ScreenshotView(
            id: "feature",
            title: "Multiple Items",
            subtitle: "Advances through more than one scene"
        ) {
            ExampleScreen(
                eyebrow: "SCREEN FLOW",
                title: "Progress stays visible",
                subtitle: "The export run should make the full capture area obvious.",
                accent: .green,
                body: {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(featureRows) { row in
                            ScreenChecklistRow(
                                icon: row.icon,
                                title: row.title,
                                detail: row.detail
                            )
                        }
                    }
                }
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
            ExampleScreen(
                eyebrow: "FINISH",
                title: "Capture complete",
                subtitle: "The last scene proves the run reaches the marker update.",
                accent: .orange,
                body: {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Done")
                                    .font(.title3.bold())
                                Text("No card frame hides the actual bounds.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ScreenChecklistRow(
                            icon: "folder.fill",
                            title: "Saved output",
                            detail: "Artifacts are written into the ignored .build directory."
                        )
                    }
                }
            )
        }
        .background(Color(red: 1.0, green: 0.96, blue: 0.92))
    }
}

private let featureRows: [FeatureRow] = [
    FeatureRow(
        icon: "play.circle.fill",
        title: "ProcessInfo autostart",
        detail: "The export script starts the app with launch environment values."
    ),
    FeatureRow(
        icon: "square.stack.3d.up.fill",
        title: "Scene handoff",
        detail: "The container advances from one screen to the next."
    ),
    FeatureRow(
        icon: "checkmark.circle.fill",
        title: "Completion marker",
        detail: "Final progress updates write capture-complete."
    )
]

private struct FeatureRow: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

private struct ExampleScreen<BodyContent: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let accent: Color
    let content: () -> BodyContent

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        accent: Color,
        @ViewBuilder body: @escaping () -> BodyContent
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.content = body
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    accent.opacity(0.22),
                    Color.black.opacity(0.02),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center) {
                    Text(eyebrow)
                        .font(.caption.bold())
                        .tracking(1.4)
                        .foregroundStyle(accent)
                    Spacer()
                    Image(systemName: "circle.grid.3x3.fill")
                        .foregroundStyle(accent.opacity(0.9))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                content()

                Spacer(minLength: 0)
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ScreenStatusRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScreenChecklistRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.green)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

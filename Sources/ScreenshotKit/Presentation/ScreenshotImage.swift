import Foundation

public struct ScreenshotImage: Sendable, Equatable, Hashable {
    public let phone: String
    public let pad: String

    public init(_ phone: String, _ pad: String) {
        self.phone = phone
        self.pad = pad
    }

    public init(phone: String, pad: String) {
        self.phone = phone
        self.pad = pad
    }

    func assetName(for deviceKind: ScreenshotDeviceKind) -> String {
        switch deviceKind {
        case .phone:
            phone
        case .pad:
            pad
        }
    }
}

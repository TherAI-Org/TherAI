import SwiftUI

enum Typography {
    // Display and titles
    static let display = Font.system(size: 34, weight: .bold, design: .rounded)
    static let displaySoft = Font.system(size: 32, weight: .semibold, design: .rounded)
    static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title = Font.system(size: 22, weight: .semibold)
    static let title2 = Font.system(size: 20, weight: .semibold)

    // Body
    static let body = Font.system(size: 17, weight: .regular)
    static let callout = Font.system(size: 16, weight: .regular)
    static let subheadline = Font.system(size: 15, weight: .regular)

    // Labels / captions
    static let label = Font.system(size: 14, weight: .medium)
    static let caption = Font.system(size: 13, weight: .regular)
    static let caption2 = Font.system(size: 12, weight: .medium)

    // Mono when needed
    static let mono = Font.system(size: 14, weight: .regular, design: .monospaced)
}

extension View {
    func titleStyle() -> some View { self.font(Typography.title) }
    func title2Style() -> some View { self.font(Typography.title2) }
    func bodyStyle() -> some View { self.font(Typography.body) }
    func calloutStyle() -> some View { self.font(Typography.callout) }
    func labelStyle() -> some View { self.font(Typography.label) }
    func captionStyle() -> some View { self.font(Typography.caption) }
    func caption2Style() -> some View { self.font(Typography.caption2) }
}



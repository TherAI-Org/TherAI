import SwiftUI

/// A thin fill that covers the top safe-area (status bar) with the system background color.
/// Keeps time/Wi‑Fi/battery readable while scrolling content beneath.
struct StatusBarBackground: View {
    /// Whether to draw a subtle divider at the bottom edge.
    var showsDivider: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let topInset: CGFloat = proxy.safeAreaInsets.top

            Color(.systemBackground)
                .frame(height: topInset)
                .ignoresSafeArea(edges: .top)
                .overlay(
                    Group {
                        if showsDivider { Divider() } else { EmptyView() }
                    }, alignment: .bottom
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        // Ensure the geometry reader does not affect layout height
        .frame(height: 0)
    }
}



import SwiftUI

struct RelationshipHealthView: View {
    @State private var expansionProgress: CGFloat = 0
    @State private var expandedContentHeight: CGFloat = 0

    private let healthInsights = RelationshipState.mocks

    let isExpanded: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var statsVM: ProfileViewModel

    @ViewBuilder
    private func healthInsightRow(title: String, value: String, description: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Spacer()

                    Text(value)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Text(description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 56, height: 56)

                            Image(systemName: "sparkles")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Relationship Health")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)

                            Text("Summary")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Text("Based on your recent interactions")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if statsVM.isFetchingHealth {
                            ThreeDotsLoadingView(color: Color(red: 0.4, green: 0.2, blue: 0.6))
                        } else {
                            Button(action: { Task { await statsVM.fetchRelationshipHealth(force: true) } }) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                    .opacity(0.9)
                            }
                            .buttonStyle(.plain)
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                            .opacity(0.7)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.1), value: isExpanded)
                    }

                    Group {
                        if let err = statsVM.healthError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(err)
                            }
                        } else if let s = statsVM.relationshipHealthSummary, !s.isEmpty {
                            Text(s)
                        } else {
                            if statsVM.hasAnyMessages {
                                Text("")
                            } else {
                                Text("Start talking to your partner to view your relationship health")
                            }
                        }
                    }
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(colorScheme == .light ? Color.white : Color(.systemGray6))
                        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
                )
                .contentShape(Rectangle())
                .onTapGesture { onTap() }

            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(healthInsights.enumerated()), id: \.offset) { index, insight in
                        let rowCount = CGFloat(healthInsights.count)
                        let step = 1.0 / max(rowCount, 1)
                        let startThreshold = CGFloat(index) * step
                        let rowProgress = max(0, min(1, (expansionProgress - startThreshold) / step))
                        healthInsightRow(
                            title: insight.title,
                            value: insight.value,
                            description: insight.description,
                            color: insight.color
                        )
                        .opacity(rowProgress)
                        .offset(x: 0, y: (1 - rowProgress) * 16)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .padding(.top, 8)
            }
            .frame(height: expandedContentHeight * expansionProgress, alignment: .top)
            .clipped()
            .background(
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(healthInsights, id: \.title) { insight in
                        healthInsightRow(
                            title: insight.title,
                            value: insight.value,
                            description: insight.description,
                            color: insight.color
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    Group {
                        if #available(iOS 26.0, *) {
                            // iOS 26+ Liquid Glass effect for hidden background
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.clear)
                                .glassEffect()
                        } else {
                            // Fallback for older iOS versions
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .opacity(0.6)
                        }
                    }
                )
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .overlay(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                let h = proxy.size.height
                                if abs(h - expandedContentHeight) > 0.5 {
                                    expandedContentHeight = h
                                }
                            }
                            .onChange(of: isExpanded) { _, _ in
                                let h = proxy.size.height
                                if abs(h - expandedContentHeight) > 0.5 {
                                    expandedContentHeight = h
                                }
                            }
                    }
                )
            )
        }
        .onAppear {
            expansionProgress = isExpanded ? 1 : 0
        }
        .onChange(of: isExpanded) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1)) {
                    expansionProgress = 1
                }
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0.1)) {
                    expansionProgress = 0
                }
            }
        }
    }
}


// MARK: - Three Dots Loader
private struct ThreeDotsLoadingView: View {
    var color: Color = .accentColor
    @State private var animate: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animate ? 1.0 : 0.5)
                    .opacity(animate ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(0.15 * Double(i)),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }
}

#Preview {
    VStack(spacing: 12) {
        RelationshipHealthView(isExpanded: true, onTap: {})
            .environmentObject(ProfileViewModel())
    }
    .padding(20)
}



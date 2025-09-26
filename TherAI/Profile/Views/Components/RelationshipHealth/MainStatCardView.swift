import SwiftUI

struct MainStatCardView: View {
    @State private var expansionProgress: CGFloat = 0
    @State private var expandedContentHeight: CGFloat = 0

    private let healthInsights = RelationshipState.mocks

    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
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

                            Text("Excellent")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Text("Based on your recent interactions")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                            .opacity(0.7)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.1), value: isExpanded)
                    }

                    Text("Your communication patterns show strong emotional intelligence and active listening skills. Both partners are engaged in meaningful conversations.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    Group {
                        if #available(iOS 26.0, *) {
                            // iOS 26+ Liquid Glass effect
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.clear)
                                .glassEffect()
                        } else {
                            // Fallback for older iOS versions
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(.systemBackground).opacity(0.8),
                                            Color(.systemBackground).opacity(0.6)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(.ultraThinMaterial)
                                )
                        }
                    }
                    .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
                )
            }
            .buttonStyle(PlainButtonStyle())

            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(healthInsights.enumerated()), id: \.offset) { index, insight in
                        let rowCount = CGFloat(healthInsights.count)
                        let step = 1.0 / max(rowCount, 1)
                        let startThreshold = CGFloat(index) * step
                        let rowProgress = max(0, min(1, (expansionProgress - startThreshold) / step))
                        HealthInsightRowView(
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
                .background(
                    Group {
                        if #available(iOS 26.0, *) {
                            // iOS 26+ Liquid Glass effect for expanded content
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
            }
            .frame(height: expandedContentHeight * expansionProgress, alignment: .top)
            .clipped()
            .background(
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(healthInsights, id: \.title) { insight in
                        HealthInsightRowView(
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


#Preview {
    VStack(spacing: 12) {
        MainStatCardView(isExpanded: true, onTap: {})
    }
    .padding(20)
}



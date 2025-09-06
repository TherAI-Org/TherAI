import SwiftUI

struct PremiumStatsCardsView: View {
    @StateObject var viewModel: PremiumStatsViewModel

    @State private var resolvedExpansionProgress: CGFloat = 0
    @State private var improvementExpansionProgress: CGFloat = 0

    @State private var resolvedExpandedContentHeight: CGFloat = 0
    @State private var improvementExpandedContentHeight: CGFloat = 0
    
    let stats: ProfileStats

    var body: some View {
        VStack(spacing: 12) {
            MainStatCardView(
                isExpanded: viewModel.isHealthExpanded,
                onTap: { viewModel.toggleHealth() }
            )

            TotalSessionsCardView(totalSessions: stats.totalSessions)

            HStack(spacing: 12) {
                ExpandableSessionCardView(
                    title: "Sessions Resolved",
                    value: "\(stats.sessionsResolved)",
                    icon: "checkmark.circle.fill",
                    gradient: [.green, .green.opacity(0.7)],
                    isExpanded: viewModel.isResolvedExpanded,
                    onTap: { viewModel.toggleResolved() }
                )

                ExpandableSessionCardView(
                    title: "Opportunities",
                    value: "5",
                    icon: "exclamationmark.triangle.fill",
                    gradient: [.orange, .orange.opacity(0.7)],
                    isExpanded: viewModel.isImprovementExpanded,
                    onTap: { viewModel.toggleImprovement() }
                )
            }

            SessionsExpandedListView(
                title: "Sessions Resolved",
                sessions: CommunicationSession.mocksResolved,
                gradient: [.green, .green.opacity(0.7)],
                expansionProgress: resolvedExpansionProgress
            )
            .frame(height: resolvedExpandedContentHeight * resolvedExpansionProgress, alignment: .top)
            .clipped()
            .opacity(resolvedExpansionProgress > 0.01 ? 1 : 0)
            .allowsHitTesting(resolvedExpansionProgress > 0.1)
            .background(
                SessionsExpandedListView(
                    title: "Sessions Resolved",
                    sessions: CommunicationSession.mocksResolved,
                    gradient: [.green, .green.opacity(0.7)]
                )
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .overlay(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                let h = proxy.size.height
                                if abs(h - resolvedExpandedContentHeight) > 0.5 {
                                    resolvedExpandedContentHeight = h
                                }
                            }
                            .onChange(of: viewModel.isResolvedExpanded) { _, _ in
                                let h = proxy.size.height
                                if abs(h - resolvedExpandedContentHeight) > 0.5 {
                                    resolvedExpandedContentHeight = h
                                }
                            }
                    }
                )
            )

            SessionsExpandedListView(
                title: "Sessions with Opportunities",
                sessions: CommunicationSession.mocksImprovement,
                gradient: [.orange, .orange.opacity(0.7)],
                expansionProgress: improvementExpansionProgress
            )
            .frame(height: improvementExpandedContentHeight * improvementExpansionProgress, alignment: .top)
            .clipped()
            .opacity(improvementExpansionProgress > 0.01 ? 1 : 0)
            .allowsHitTesting(improvementExpansionProgress > 0.1)
            .background(
                SessionsExpandedListView(
                    title: "Sessions with Opportunities",
                    sessions: CommunicationSession.mocksImprovement,
                    gradient: [.orange, .orange.opacity(0.7)]
                )
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .overlay(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                let h = proxy.size.height
                                if abs(h - improvementExpandedContentHeight) > 0.5 {
                                    improvementExpandedContentHeight = h
                                }
                            }
                            .onChange(of: viewModel.isImprovementExpanded) { _, _ in
                                let h = proxy.size.height
                                if abs(h - improvementExpandedContentHeight) > 0.5 {
                                    improvementExpandedContentHeight = h
                                }
                            }
                    }
                )
            )
        }
        .onAppear {
            resolvedExpansionProgress = viewModel.isResolvedExpanded ? 1 : 0
            improvementExpansionProgress = viewModel.isImprovementExpanded ? 1 : 0
        }
        .onChange(of: viewModel.isResolvedExpanded) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1)) {
                    resolvedExpansionProgress = 1
                }
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0.1)) {
                    resolvedExpansionProgress = 0
                }
            }
        }
        .onChange(of: viewModel.isImprovementExpanded) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1)) {
                    improvementExpansionProgress = 1
                }
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0.1)) {
                    improvementExpansionProgress = 0
                }
            }
        }
    }
}


#Preview {
    PremiumStatsCardsView(
        viewModel: PremiumStatsViewModel(),
        stats: ProfileStats(
            totalSessions: 24,
            newSessions: 0,
            averageRating: 4.8,
            sessionsResolved: 18,
            sessionsNeedsImprovement: 6
        )
    )
    .padding(20)
}



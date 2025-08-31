import SwiftUI

// MARK: - Premium Stats Cards with Relationship Health
struct PremiumStatsCards: View {
    let stats: ProfileStats
    @State private var isHealthExpanded = false
    @State private var isResolvedExpanded = false
    @State private var isImprovementExpanded = false

    // Expansion progress states for smooth animations
    @State private var healthExpansionProgress: CGFloat = 0
    @State private var resolvedExpansionProgress: CGFloat = 0
    @State private var improvementExpansionProgress: CGFloat = 0

    // Content height measurements
    @State private var healthExpandedContentHeight: CGFloat = 0
    @State private var resolvedExpandedContentHeight: CGFloat = 0
    @State private var improvementExpandedContentHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            // Main Relationship Health Card - Expandable
            MainStatCard(
                title: "Relationship Health",
                value: "Excellent",
                subtitle: "Based on your recent interactions",
                description: "Your communication patterns show strong emotional intelligence and active listening skills. Both partners are engaged in meaningful conversations.",
                icon: "sparkles",
                gradient: [.blue, .pink],
                isExpanded: isHealthExpanded,
                onTap: { isHealthExpanded.toggle() }
            )
            
            // Total Sessions - Full width
            TotalSessionsCard(totalSessions: stats.totalSessions)
            
            // Secondary stats row - Resolved and Needs Improvement
            HStack(spacing: 12) {
                ExpandableSessionCard(
                    title: "Sessions Resolved",
                    value: "\(stats.sessionsResolved)",
                    icon: "checkmark.circle.fill",
                    gradient: [.green, .green.opacity(0.7)],
                    isExpanded: isResolvedExpanded,
                    onTap: { 
                        if isImprovementExpanded {
                            isImprovementExpanded = false
                        }
                        isResolvedExpanded.toggle()
                    },
                    sessions: createMockResolvedSessions()
                )
                
                ExpandableSessionCard(
                    title: "Needs Improvement",
                    value: "5",
                    icon: "exclamationmark.triangle.fill",
                    gradient: [.orange, .orange.opacity(0.7)],
                    isExpanded: isImprovementExpanded,
                    onTap: { 
                        if isResolvedExpanded {
                            isResolvedExpanded = false
                        }
                        isImprovementExpanded.toggle()
                    },
                    sessions: createMockImprovementSessions()
                )
            }
            
            // Full-width expanded content below the cards with smooth animations
            // Always show content but control visibility through animation progress
            ExpandedSessionsView(
                title: "Sessions Resolved",
                sessions: createMockResolvedSessions(),
                gradient: [.green, .green.opacity(0.7)],
                expansionProgress: resolvedExpansionProgress
            )
            .frame(height: resolvedExpandedContentHeight * resolvedExpansionProgress, alignment: .top)
            .clipped()
            .opacity(resolvedExpansionProgress > 0.01 ? 1 : 0) // Smooth opacity transition
            .allowsHitTesting(resolvedExpansionProgress > 0.1) // Disable interaction during closing
            .background(
                // Hidden measuring view to determine full expanded height
                ExpandedSessionsView(
                    title: "Sessions Resolved",
                    sessions: createMockResolvedSessions(),
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
                            .onChange(of: isResolvedExpanded) { _, _ in
                                let h = proxy.size.height
                                if abs(h - resolvedExpandedContentHeight) > 0.5 {
                                    resolvedExpandedContentHeight = h
                                }
                            }
                    }
                )
            )

            ExpandedSessionsView(
                title: "Sessions Needing Improvement",
                sessions: createMockImprovementSessions(),
                gradient: [.orange, .orange.opacity(0.7)],
                expansionProgress: improvementExpansionProgress
            )
            .frame(height: improvementExpandedContentHeight * improvementExpansionProgress, alignment: .top)
            .clipped()
            .opacity(improvementExpansionProgress > 0.01 ? 1 : 0) // Smooth opacity transition
            .allowsHitTesting(improvementExpansionProgress > 0.1) // Disable interaction during closing
            .background(
                // Hidden measuring view to determine full expanded height
                ExpandedSessionsView(
                    title: "Sessions Needing Improvement",
                    sessions: createMockImprovementSessions(),
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
                            .onChange(of: isImprovementExpanded) { _, _ in
                                let h = proxy.size.height
                                if abs(h - improvementExpandedContentHeight) > 0.5 {
                                    improvementExpandedContentHeight = h
                                }
                            }
                    }
                )
            )
        }
        // Drive the expansion progress with spring animation for open/close
        .onAppear {
            resolvedExpansionProgress = isResolvedExpanded ? 1 : 0
            improvementExpansionProgress = isImprovementExpanded ? 1 : 0
        }
        .onChange(of: isResolvedExpanded) { _, newValue in
            if newValue {
                // Opening - smooth expansion with cascading reveal
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1)) {
                    resolvedExpansionProgress = 1
                }
            } else {
                // Closing - smooth collapse with less bounce
                withAnimation(.spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0.1)) {
                    resolvedExpansionProgress = 0
                }
            }
        }
        .onChange(of: isImprovementExpanded) { _, newValue in
            if newValue {
                // Opening - smooth expansion with cascading reveal
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1)) {
                    improvementExpansionProgress = 1
                }
            } else {
                // Closing - smooth collapse with less bounce
                withAnimation(.spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0.1)) {
                    improvementExpansionProgress = 0
                }
            }
        }
    }
    
    // Mock data for resolved sessions - 8 total
    private func createMockResolvedSessions() -> [SessionItem] {
        return [
            SessionItem(title: "Communication Breakthrough", date: "2 days ago", duration: "45 min", status: "Resolved"),
            SessionItem(title: "Trust Building Exercise", date: "1 week ago", duration: "30 min", status: "Resolved"),
            SessionItem(title: "Future Planning Discussion", date: "2 weeks ago", duration: "60 min", status: "Resolved"),
            SessionItem(title: "Emotional Intelligence Workshop", date: "3 weeks ago", duration: "55 min", status: "Resolved"),
            SessionItem(title: "Relationship Goals Setting", date: "1 month ago", duration: "40 min", status: "Resolved"),
            SessionItem(title: "Conflict Resolution Practice", date: "1 month ago", duration: "50 min", status: "Resolved"),
            SessionItem(title: "Communication Skills Review", date: "2 months ago", duration: "35 min", status: "Resolved"),
            SessionItem(title: "Trust Building Activities", date: "2 months ago", duration: "45 min", status: "Resolved")
        ]
    }
    
    // Mock data for improvement sessions - 5 total
    private func createMockImprovementSessions() -> [SessionItem] {
        return [
            SessionItem(title: "Conflict Resolution", date: "3 days ago", duration: "40 min", status: "In Progress"),
            SessionItem(title: "Emotional Expression", date: "1 week ago", duration: "35 min", status: "Needs Work"),
            SessionItem(title: "Active Listening Practice", date: "2 weeks ago", duration: "50 min", status: "Review Required"),
            SessionItem(title: "Anger Management Skills", date: "3 weeks ago", duration: "45 min", status: "Needs Work"),
            SessionItem(title: "Stress Communication", date: "1 month ago", duration: "40 min", status: "In Progress")
        ]
    }
}

// MARK: - Main Premium Stat Card
struct MainStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let description: String
    let icon: String
    let gradient: [Color]
    let isExpanded: Bool
    let onTap: () -> Void
    
    private let healthInsights = [
        HealthInsight(title: "Communication Score", value: "9.2/10", description: "Excellent verbal and non-verbal communication patterns", color: .blue),
        HealthInsight(title: "Trust Level", value: "Strong", description: "Both partners demonstrate high trust and reliability", color: .green),
        HealthInsight(title: "Emotional Connection", value: "Strong", description: "Strong emotional bonding and empathy shown", color: .pink),
        HealthInsight(title: "Conflict Resolution", value: "Effective", description: "Healthy conflict resolution strategies in place", color: .purple)
    ]
    @State private var expansionProgress: CGFloat = 0
    @State private var expandedContentHeight: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        // Icon with gradient background
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: gradient,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: icon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(value)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text(subtitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Expand/collapse indicator
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .opacity(0.7)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.1), value: isExpanded)
                    }
                    
                    // Description text
                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(.systemBackground),
                                    Color(.systemBackground).opacity(0.95)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded content with measured height and progress-based reveal
            ZStack(alignment: .top) {
                // Visible content masked by expansion height
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(healthInsights.enumerated()), id: \.offset) { index, insight in
                        // Compute per-row reveal progress based on overall expansion progress
                        let rowCount = CGFloat(healthInsights.count)
                        let step = 1.0 / max(rowCount, 1)
                        let startThreshold = CGFloat(index) * step
                        let rowProgress = max(0, min(1, (expansionProgress - startThreshold) / step))
                        HealthInsightRow(
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
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6).opacity(0.3))
                )
                .padding(.top, 8)
            }
            .frame(height: expandedContentHeight * expansionProgress, alignment: .top)
            .clipped()
            // Hidden measuring view to determine full expanded height
            .background(
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(healthInsights, id: \.title) { insight in
                        HealthInsightRow(
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
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6).opacity(0.3))
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
        // Drive the expansion progress with spring animation for open/close
        .onAppear {
            expansionProgress = isExpanded ? 1 : 0
        }
        .onChange(of: isExpanded) { _, newValue in
            if newValue {
                // Opening - smooth expansion
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1)) {
                    expansionProgress = 1
                }
            } else {
                // Closing - smooth collapse with less bounce
                withAnimation(.spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0.1)) {
                    expansionProgress = 0
                }
            }
        }
    }
}

// MARK: - Premium Stat Card
struct PremiumStatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            Color(.systemBackground).opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Total Sessions Card
struct TotalSessionsCard: View {
    let totalSessions: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Sessions")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("\(totalSessions)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            Color(.systemBackground).opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        )
    }
}

// MARK: - Expandable Session Card
struct ExpandableSessionCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    let isExpanded: Bool
    let onTap: () -> Void
    let sessions: [SessionItem]
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Content
                VStack(spacing: 3) {
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Expand/collapse indicator
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .opacity(0.7)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.spring(response: 0.25, dampingFraction: 0.5, blendDuration: 0.1), value: isExpanded)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.systemBackground),
                                Color(.systemBackground).opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PremiumStatsCards(stats: ProfileStats(
        totalSessions: 24,
        newSessions: 0,
        averageRating: 4.8,
        sessionsResolved: 18,
        sessionsNeedsImprovement: 6
    ))
    .padding(20)
}

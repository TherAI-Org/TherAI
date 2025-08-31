import SwiftUI

// MARK: - Health Insight Row
struct HealthInsightRow: View {
    let title: String
    let value: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            // Color indicator with higher contrast
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
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        )
    }
}

// MARK: - Relationship Insights Section
struct RelationshipInsightsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Relationship Insights")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                InsightCard(
                    title: "Communication",
                    value: "Great",
                    icon: "message.fill",
                    color: .blue
                )
                
                InsightCard(
                    title: "Trust Level",
                    value: "Strong",
                    icon: "lock.shield.fill",
                    color: .green
                )
                
                InsightCard(
                    title: "Future Goals",
                    value: "Aligned",
                    icon: "target",
                    color: .purple
                )
                
                InsightCard(
                    title: "Intimacy",
                    value: "Deep",
                    icon: "heart.fill",
                    color: .pink
                )
            }
        }
    }
}

// MARK: - Insight Card
struct InsightCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }
            
            // Content
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
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
                .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        HealthInsightRow(
            title: "Communication Score",
            value: "9.2/10",
            description: "Excellent verbal and non-verbal communication patterns",
            color: .blue
        )
        
        RelationshipInsightsSection()
    }
    .padding(20)
}

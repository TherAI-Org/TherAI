import SwiftUI

struct RelationshipInsightsSectionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Relationship Insights")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                RelationshipStatisticsView(
                    title: "Communication",
                    value: "Great",
                    icon: "message.fill",
                    color: .blue
                )

                RelationshipStatisticsView(
                    title: "Trust Level",
                    value: "Strong",
                    icon: "lock.shield.fill",
                    color: .green
                )

                RelationshipStatisticsView(
                    title: "Future Goals",
                    value: "Aligned",
                    icon: "target",
                    color: .purple
                )

                RelationshipStatisticsView(
                    title: "Intimacy",
                    value: "Deep",
                    icon: "heart.fill",
                    color: .pink
                )
            }
        }
    }
}


#Preview {
    RelationshipInsightsSectionView()
        .padding(20)
}



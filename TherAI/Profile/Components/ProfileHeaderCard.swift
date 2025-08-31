import SwiftUI

// MARK: - Profile Header Card
struct ProfileHeaderCard: View {
    let userProfile: UserProfile
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Pictures Row with overlapping design
            HStack(spacing: -20) {
                // User Avatar with blue gradient
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .pink.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                    
                    // White border
                    Circle()
                        .fill(.white)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    
                    // Main avatar with blue gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text("M")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                }
                
                // Partner Avatar with pink gradient
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.pink.opacity(0.3), .blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                    
                    // White border
                    Circle()
                        .fill(.white)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    
                    // Main avatar with pink gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.pink, .pink.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text("S")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                }
            }
            
            // Premium relationship info
            VStack(spacing: 10) {
                // "Together since" text
                Text("Together since")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                // Month and year
                Text(userProfile.relationshipStartMonthYear)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .tracking(0.5)
            }
            
            // Premium relationship duration badge
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
                    .font(.system(size: 12))
                
                Text("\(userProfile.relationshipDuration) of love")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.pink.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(.pink.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
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
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }
}

#Preview {
    ProfileHeaderCard(userProfile: UserProfile(
        firstName: "Michael",
        lastName: "Johnson",
        partnerFirstName: "Sarah",
        partnerLastName: "Smith",
        relationshipStartDate: Date(),
        relationshipDuration: "2 years",
        personalityType: "Analytical"
    ))
    .padding(20)
}

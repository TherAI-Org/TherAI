import SwiftUI

// MARK: - Profile Demo View
// This view demonstrates how to easily integrate the ProfileView into your existing app
struct ProfileDemoView: View {
    @State private var showingProfile = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Your existing app content can go here
            VStack(spacing: 20) {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                    .font(.system(size: 60))
                
                Text("TherAI - AI Therapy App")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Your brother's chat interface will go here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Easy integration button
            Button(action: {
                showingProfile = true
            }) {
                HStack {
                    Image(systemName: "person.circle.fill")
                    Text("View Profile")
                }
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            
            // Integration instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("Integration Instructions:")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Import ProfileView in your main view")
                    Text("2. Add navigation or present ProfileView")
                    Text("3. Customize data sources as needed")
                    Text("4. Style to match your app theme")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
    }
}

#Preview {
    ProfileDemoView()
}

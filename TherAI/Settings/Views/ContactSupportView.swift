import SwiftUI

struct ContactSupportView: View {
    @State private var showingMailComposer = false
    @State private var showingCopyConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header section
            VStack(spacing: 16) {
                Image(systemName: "envelope.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Need Help?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("We're here to help! Reach out to our support team for any questions or assistance.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            
            Spacer()
            
            // Email section
            VStack(spacing: 24) {
                // Minimalistic email button
                Button(action: {
                    if let url = URL(string: "mailto:team.therai@gmail.com") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text("Email Support")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 1)
                            .background(Color.blue.opacity(0.05))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Email address with copy functionality
                VStack(spacing: 12) {
                    Text("Or copy our email address:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Text("team.therai@gmail.com")
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.systemGray6))
                            )
                        
                        Button(action: {
                            UIPasteboard.general.string = "team.therai@gmail.com"
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingCopyConfirmation = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showingCopyConfirmation = false
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showingCopyConfirmation ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(showingCopyConfirmation ? .green : .blue)
                                
                                Text(showingCopyConfirmation ? "Copied!" : "Copy")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(showingCopyConfirmation ? .green : .blue)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(showingCopyConfirmation ? Color.green : Color.blue, lineWidth: 1)
                                    .background((showingCopyConfirmation ? Color.green : Color.blue).opacity(0.05))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    ContactSupportView()
}



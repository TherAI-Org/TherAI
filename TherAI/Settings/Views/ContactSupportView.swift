import SwiftUI

struct ContactSupportView: View {
    @State private var showingMailComposer = false
    @State private var isCopied: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header section
            VStack(spacing: 16) {
                Image(systemName: "envelope.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                
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
            VStack(spacing: 20) {
                let accent = Color(red: 0.4, green: 0.2, blue: 0.6)
                Button(action: {
                    Haptics.impact(.medium)
                    if let url = URL(string: "mailto:team.therai@gmail.com") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Email Support")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [accent, accent.opacity(0.9)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: accent.opacity(0.25), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Tap to open your email app")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Copyable email card
                MinimalCardView {
                    HStack(spacing: 12) {
                        IconButtonLabelView(systemName: "envelope")

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Support Email")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text("team.therai@gmail.com")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        }

                        Spacer()

                        Button(action: {
                            UIPasteboard.general.string = "team.therai@gmail.com"
                            Haptics.notification(.success)
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { isCopied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { isCopied = false }
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                Text(isCopied ? "Copied" : "Copy")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIPasteboard.general.string = "team.therai@gmail.com"
                        Haptics.notification(.success)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { isCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { isCopied = false }
                        }
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



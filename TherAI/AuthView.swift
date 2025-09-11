import SwiftUI
import AuthenticationServices
import UIKit

struct AuthView: View {
    @StateObject private var authService = AuthService.shared

    var body: some View {
        if authService.isAuthenticated {
            NavigationView {
                ChatView()
            }
        } else {
            VStack(spacing: 30) {
                // App Logo/Title
                VStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))

                    Text("TherAI")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Your AI Chat Assistant")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Sign In Buttons
                VStack(spacing: 16) {
                    Button(action: { Task { await authService.signInWithGoogle() } }) {
                        HStack { Image(systemName: "globe").font(.title2); Text("Sign in with Google").font(.headline) }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        if let anchor = getPresentationAnchor() {
                            Task { await authService.signInWithApple(presentationAnchor: anchor) }
                        }
                    }) {
                        HStack { Image(systemName: "applelogo").font(.title2); Text("Sign in with Apple").font(.headline) }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)
            }
            .padding()
        }
    }

    private func getPresentationAnchor() -> ASPresentationAnchor? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

#Preview {
    AuthView()
}

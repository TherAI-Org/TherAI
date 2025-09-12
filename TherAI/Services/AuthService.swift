import Foundation
import Supabase
import AuthenticationServices


class AuthService: ObservableObject {

    static let shared = AuthService()

    let client: SupabaseClient

    @Published var isAuthenticated = false
    @Published var currentUser: User?

    private let redirectURL: URL

    private let appleService = AppleSignInService()
    private let googleService = GoogleSignInService()

    private init() {
        guard let supabaseURL = AuthService.getInfoPlistValue(for: "SUPABASE_URL") as? String,
              let supabaseKey = AuthService.getInfoPlistValue(for: "SUPABASE_PUBLISHABLE_KEY") as? String else {
            fatalError("Missing Supabase configuration in Secrets.plist")
        }

        let projectRef = URL(string: supabaseURL)?.host?.components(separatedBy: ".").first ?? ""
        let scheme = "supabase-\(projectRef)"
        guard let redirectURL = URL(string: "\(scheme)://auth/callback") else {
            fatalError("Failed to construct redirect URL for Supabase OAuth")
        }
        self.redirectURL = redirectURL

        client = SupabaseClient(
            supabaseURL: URL(string: supabaseURL)!,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: KeychainLocalStorage(),
                    redirectToURL: redirectURL
                )
            )
        )

        checkAuthStatus()  // Initialises auth state on app launch to check for an existing Supabase session
    }

    static func getInfoPlistValue(for key: String) -> Any? {
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let value = plist[key] {
            return value
        }

        return nil
    }

    private func checkAuthStatus() {
        Task {
            do {
                let session = try await client.auth.session
                await MainActor.run {
                    self.isAuthenticated = true
                    self.currentUser = session.user
                }
            } catch {
                await MainActor.run {
                    self.isAuthenticated = false
                    self.currentUser = nil
                }
            }
        }
    }

    func signInWithGoogle() async {
        do {
            let session = try await googleService.signIn(redirectURL: redirectURL, client: client)
            await MainActor.run {
                self.isAuthenticated = true
                self.currentUser = session.user
            }
        } catch {
            print("Google sign-in error: \(error)")
        }
    }

    func signInWithApple(presentationAnchor anchor: ASPresentationAnchor) async {
        do {
            let session = try await appleService.signIn(presentationAnchor: anchor, client: client)
            await MainActor.run {
                self.isAuthenticated = true
                self.currentUser = session.user
            }
        } catch {
            print("Apple sign-in error: \(error)")
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
            }
        } catch {
            print("Sign out error: \(error)")
        }
    }

    func getAccessToken() async -> String? {
        do {
            let session = try await client.auth.session
            return session.accessToken
        } catch {
            return nil
        }
    }
}

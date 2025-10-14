import Foundation
import Supabase
import AuthenticationServices


class AuthService: ObservableObject {

    static let shared = AuthService()

    let client: SupabaseClient

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoadingInitialData = false

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
                    // Don't set loading state for existing sessions
                    self.isLoadingInitialData = false
                }
            } catch {
                await MainActor.run {
                    self.isAuthenticated = false
                    self.currentUser = nil
                    self.isLoadingInitialData = false
                }
            }
        }
    }

    func signInWithGoogle() async {
        do {
            let session = try await googleService.signIn(redirectURL: redirectURL, client: client)
            await MainActor.run {
                self.isLoadingInitialData = true
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
                self.isLoadingInitialData = true
                self.isAuthenticated = true
                self.currentUser = session.user
            }
        } catch {
            print("Apple sign-in error: \(error)")
        }
    }

    func signOut() async {
        // Immediately update UI state
        await MainActor.run {
            self.isAuthenticated = false
            self.currentUser = nil
        }

        // Then perform the actual sign out
        do {
            try await client.auth.signOut()
        } catch {
            print("Sign out error: \(error)")
            // If sign out fails, restore the auth state
            checkAuthStatus()
        }
    }

    func getAccessToken() async -> String? {
        do {
            let session = try await client.auth.session
            let token = session.accessToken
            print("ACCESS_TOKEN: \(token)")
            return token
        } catch {
            return nil
        }
    }

    func setInitialDataLoaded() {
        Task { @MainActor in
            self.isLoadingInitialData = false
        }
    }
}

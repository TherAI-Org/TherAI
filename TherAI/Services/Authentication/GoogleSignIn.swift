import Foundation
import Supabase

final class GoogleSignIn {
    func signIn(redirectURL: URL, client: SupabaseClient) async throws -> Session {
        let session = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: redirectURL,
            queryParams: [(name: "prompt", value: "select_account")]
        )
        return session
    }
}



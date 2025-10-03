import Foundation
import SwiftUI

final class ProfileViewModel: ObservableObject {
    @Published var isHealthExpanded: Bool = false
    @Published var isResolvedExpanded: Bool = false
    @Published var isImprovementExpanded: Bool = false

    @Published var relationshipHealthSummary: String? = nil
    @Published var lastHealthRunAt: Date? = nil
    @Published var isFetchingHealth: Bool = false
    @Published var healthError: String? = nil
    @Published var hasAnyMessages: Bool = true

    private let lastRunKey = "profile.relationshipHealth.lastRunAt"
    private let summaryKey = "profile.relationshipHealth.summary"
    private let scheduledRefreshHour = 9 // 9 AM local

    init() {
        if let iso = UserDefaults.standard.string(forKey: lastRunKey) {
            if let d = ISO8601DateFormatter().date(from: iso) { lastHealthRunAt = d }
        }
        if let cachedSummary = UserDefaults.standard.string(forKey: summaryKey) {
            relationshipHealthSummary = cachedSummary
        }
    }

    func toggleHealth() {
        isHealthExpanded.toggle()
    }

    func toggleResolved() {
        if isImprovementExpanded {
            isImprovementExpanded = false
        }
        isResolvedExpanded.toggle()
    }

    func toggleImprovement() {
        if isResolvedExpanded {
            isResolvedExpanded = false
        }
        isImprovementExpanded.toggle()
    }

    @MainActor
    func fetchRelationshipHealth(force: Bool = false) async {
        if isFetchingHealth { return }
        guard let token = await AuthService.shared.getAccessToken() else { return }
        isFetchingHealth = true
        healthError = nil
        do {
            let res = try await BackendService.shared.fetchRelationshipHealth(accessToken: token, lastRunAt: lastHealthRunAt, force: force)
            relationshipHealthSummary = res.summary
            hasAnyMessages = res.has_any_messages
            if let date = ISO8601DateFormatter().date(from: res.last_run_at) {
                lastHealthRunAt = date
            } else {
                lastHealthRunAt = Date()
            }
            if let d = lastHealthRunAt {
                let iso = ISO8601DateFormatter().string(from: d)
                UserDefaults.standard.set(iso, forKey: lastRunKey)
            }
            // Cache the latest summary locally so we can show it instantly next time
            UserDefaults.standard.set(relationshipHealthSummary ?? "", forKey: summaryKey)
        } catch {
            healthError = error.localizedDescription
        }
        isFetchingHealth = false
    }

    func maybeRefreshOnAppear(now: Date = Date()) async {
        // Always fetch on first load to populate hasAnyMessages and summary
        if relationshipHealthSummary == nil {
            await fetchRelationshipHealth(force: false)
            return
        }
        if shouldRefreshNow(now: now) {
            await fetchRelationshipHealth(force: false)
        }
    }

    func shouldRefreshNow(now: Date = Date()) -> Bool {
        guard let last = lastHealthRunAt else { return true }
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: now)
        components.hour = scheduledRefreshHour
        components.minute = 0
        components.second = 0
        let todayScheduled = cal.date(from: components) ?? now
        let latestScheduledBeforeNow: Date = (todayScheduled > now) ? cal.date(byAdding: .day, value: -1, to: todayScheduled)! : todayScheduled
        return last < latestScheduledBeforeNow
    }
}



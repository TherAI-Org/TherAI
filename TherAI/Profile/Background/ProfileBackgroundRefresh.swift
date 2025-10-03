import Foundation
import BackgroundTasks

enum ProfileBackgroundRefresh {

	static let taskIdentifier = "ai.therai.relationshipHealth.refresh"
	private static let lastRunKey = "profile.relationshipHealth.lastRunAt"
	private static let summaryKey = "profile.relationshipHealth.summary"
	private static let scheduledRefreshHour = 9 // 9 AM local

	static func register() {
		BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
			// Always schedule the next refresh
			scheduleNext()
			let expirationHandler = {
				task.setTaskCompleted(success: false)
			}
			Task {
				let success = await runRefresh()
				if !Task.isCancelled {
					task.setTaskCompleted(success: success)
				}
			}
			task.expirationHandler = expirationHandler
		}
	}

	static func scheduleNext(now: Date = Date()) {
		let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
		request.earliestBeginDate = nextScheduledDate(from: now)
		_ = try? BGTaskScheduler.shared.submit(request)
	}

	private static func nextScheduledDate(from now: Date) -> Date {
		let cal = Calendar.current
		var comps = cal.dateComponents([.year, .month, .day], from: now)
		comps.hour = scheduledRefreshHour
		comps.minute = 0
		comps.second = 0
		let today = cal.date(from: comps) ?? now
		return (today > now) ? today : (cal.date(byAdding: .day, value: 1, to: today) ?? now)
	}

	@discardableResult
	private static func runRefresh() async -> Bool {
		guard let token = await AuthService.shared.getAccessToken() else { return false }
		let lastRunISO = UserDefaults.standard.string(forKey: lastRunKey)
		let lastRunDate: Date? = lastRunISO.flatMap { ISO8601DateFormatter().date(from: $0) }
		do {
			let res = try await BackendService.shared.fetchRelationshipHealth(accessToken: token, lastRunAt: lastRunDate, force: false)
			UserDefaults.standard.set(res.summary, forKey: summaryKey)
			UserDefaults.standard.set(res.last_run_at, forKey: lastRunKey)
			return true
		} catch {
			return false
		}
	}
}



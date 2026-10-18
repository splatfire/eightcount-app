import Foundation
import Observation
import UserNotifications

/// Remembers on which days you practised (for the streak on the home
/// screen) and, if you want, reminds you to review a dance a couple of days
/// later.
///
/// A day counts once you've played a project's video for a minute in total,
/// or recorded a take. Stored in UserDefaults (just a list of dates), so it
/// never leaves the iPhone.
@MainActor
@Observable
final class PracticeLog {
    static let shared = PracticeLog()

    /// Practice days as "yyyy-MM-dd" (local time).
    private(set) var days: Set<String>

    private static let daysKey = "practiceDays"
    static let remindersKey = "reviewReminders"
    /// Daily streak reminder on/off, and the time as minutes after midnight (7 pm).
    static let streakReminderKey = "streakReminder"
    static let streakReminderMinutesKey = "streakReminderMinutes"
    /// Review reminder: this many days after you last practised a project, at 18:00.
    static let reviewAfterDays = 2

    private init() {
        days = Set(UserDefaults.standard.stringArray(forKey: Self.daysKey) ?? [])
    }

    // MARK: - Streak

    /// Days in a row up to today (or up to yesterday, if you haven't
    /// practised yet today – the streak isn't lost until the day is over).
    var streak: Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: .now)
        if !days.contains(Self.key(day)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(Self.key(day)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    var practisedToday: Bool { days.contains(Self.key(.now)) }

    /// Call when you've practised `project` (played a minute / recorded a take).
    func recordPractice(of project: Project) {
        let today = Self.key(.now)
        let isNewDay = !days.contains(today)
        if isNewDay {
            days.insert(today)
            // Keep about a year.
            let sorted = days.sorted()
            if sorted.count > 400 { days = Set(sorted.suffix(400)) }
            UserDefaults.standard.set(Array(days), forKey: Self.daysKey)
        }
        if UserDefaults.standard.bool(forKey: Self.remindersKey) {
            scheduleReview(of: project)
        }
        // Today's reminder should disappear once this day counts.
        if isNewDay {
            scheduleStreakReminders()
        }
    }

    /// One reminder a day for the next week, at the time chosen on the home screen.
    /// A missed day ends the streak, so only the first upcoming one names the number.
    func scheduleStreakReminders() {
        let center = UNUserNotificationCenter.current()
        let identifiers = (0...6).map { "streak-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard UserDefaults.standard.bool(forKey: Self.streakReminderKey) else { return }

        // A missing value means 7 pm. Keep it on the clock or iOS drops the notification.
        let stored = UserDefaults.standard.object(forKey: Self.streakReminderMinutesKey) as? Int ?? 1140
        let minutes = min(max(stored, 0), 23 * 60 + 59)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let streakCount = streak
        let practised = practisedToday

        for offset in 0...6 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
            var when = calendar.dateComponents([.year, .month, .day], from: day)
            when.hour = minutes / 60
            when.minute = minutes % 60
            if offset == 0 {
                if practised { continue }
                guard let fire = calendar.date(from: when), fire > .now else { continue }
            }

            let content = UNMutableNotificationContent()
            content.sound = .default
            if offset == 0, streakCount > 0 {
                content.title = "Keep your \(streakCount)-day streak! 🔥"
                content.body = "A minute of practice today keeps it going."
            } else if offset == 0 {
                content.title = "Time to dance! 💃"
                content.body = "Practise a minute today to start a streak."
            } else if offset == 1, practised, streakCount > 0 {
                content.title = "Keep your \(streakCount)-day streak! 🔥"
                content.body = "Practise a minute today so you don't lose it."
            } else {
                content.title = "Your dances miss you 💃"
                content.body = "Practise a minute today to start a new streak."
            }
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            let request = UNNotificationRequest(identifier: "streak-\(offset)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    private static func key(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: - Review reminders

    /// Asks iOS for permission to show notifications. Returns true if allowed.
    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// One reminder per project, `reviewAfterDays` days from now at 18:00.
    /// Practising again moves it (same identifier replaces the old one).
    func scheduleReview(of project: Project) {
        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: Self.reviewAfterDays, to: .now) else { return }
        var when = calendar.dateComponents([.year, .month, .day], from: day)
        when.hour = 18
        when.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Time to review \"\(project.title)\""
        content.body = "A quick run-through now helps you remember the dance. Try a memory test!"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
        let request = UNNotificationRequest(identifier: Self.identifier(for: project),
                                            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelReview(of project: Project) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.identifier(for: project)])
    }

    func cancelAllReviews() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix("review-") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private static func identifier(for project: Project) -> String {
        "review-\(project.id.uuidString)"
    }
}

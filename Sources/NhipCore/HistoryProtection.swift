import Foundation

/// Enforced at the application transaction boundary, including undo and stale editors.
/// Explicit full restore/reset use their existing confirmation flow separately.
public enum HistoryProtection {
    public static let message = "Ngày đã kết thúc. Chỉ được xem dữ liệu cũ, không thể thêm, sửa hoặc xoá."
    public static func isPast(_ date: Date, journal: Journal, now: Date = Date()) -> Bool {
        date < journal.preferences.calendar.startOfDay(for: now)
    }
    public static func canEdit(_ entry: Entry, journal: Journal, now: Date = Date()) -> Bool {
        !isPast(entry.start, journal: journal, now: now)
    }
    public static func validateChange(from original: Journal, to updated: Journal, now: Date = Date()) throws {
        try Deadlines.validateChange(from: original, to: updated, now: now)
        let calendar = original.preferences.calendar, cutoff = calendar.startOfDay(for: now)
        let fail = JournalError.invalid(message)
        let oldEntries = Dictionary(uniqueKeysWithValues: original.entries.map { ($0.id, $0) })
        let newEntries = Dictionary(uniqueKeysWithValues: updated.entries.map { ($0.id, $0) })
        for entry in original.entries where entry.start < cutoff {
            guard newEntries[entry.id] == entry else { throw fail }
        }
        var allowedPastEntries: Set<UUID> = []
        let oldPersonal = original.personalHistory?.sessions ?? [], newPersonal = updated.personalHistory?.sessions ?? []
        let personalByID = Dictionary(uniqueKeysWithValues: newPersonal.map { ($0.id, $0) })
        for old in oldPersonal where old.start < cutoff {
            guard let changed = personalByID[old.id] else { throw fail }
            if changed == old { continue }
            var identity = changed; identity.end = old.end; identity.entryID = old.entryID
            guard old.end == nil, identity == old, let end = changed.end, end >= cutoff, end <= now.addingTimeInterval(1),
                  let id = changed.entryID, oldEntries[id] == nil, let entry = newEntries[id],
                  entry.source == "personal-timer", entry.start == old.start, entry.end == end, entry.activityID == old.activityID else { throw fail }
            allowedPastEntries.insert(id)
        }
        let oldPersonalIDs = Set(oldPersonal.filter { $0.start < cutoff }.map(\.id))
        guard newPersonal.filter({ $0.start < cutoff }).allSatisfy({ oldPersonalIDs.contains($0.id) }) else { throw fail }
        let oldSleep = original.sleepHistory?.sessions ?? [], newSleep = updated.sleepHistory?.sessions ?? []
        let sleepByID = Dictionary(uniqueKeysWithValues: newSleep.map { ($0.id, $0) })
        for old in oldSleep where old.start < cutoff {
            guard let changed = sleepByID[old.id] else { throw fail }
            if changed == old { continue }
            var identity = changed; identity.end = old.end; identity.restEntryID = old.restEntryID
            guard old.end == nil, identity == old, let end = changed.end, end >= cutoff, end <= now.addingTimeInterval(1),
                  let id = changed.restEntryID, oldEntries[id] == nil, let entry = newEntries[id],
                  entry.source == "sleep", entry.start == old.start, entry.end == end,
                  entry.activityID == updated.sleepHistory?.restActivityID else { throw fail }
            allowedPastEntries.insert(id)
        }
        let oldSleepIDs = Set(oldSleep.filter { $0.start < cutoff }.map(\.id))
        guard newSleep.filter({ $0.start < cutoff }).allSatisfy({ oldSleepIDs.contains($0.id) }) else { throw fail }
        for entry in updated.entries where entry.start < cutoff {
            if let old = oldEntries[entry.id] {
                guard old.start < cutoff else { throw fail }
                continue
            }
            if allowedPastEntries.contains(entry.id) { continue }
            // A live five-minute interval may straddle midnight. Its actual answer is
            // allowed briefly; older delivered notifications cannot backfill a past day.
            let liveCrossing = entry.source == "checkin" && original.intervals.contains {
                $0.start < cutoff && $0.end > cutoff && $0.end <= now && now.timeIntervalSince($0.end) < 60
                    && entry.start >= $0.start && entry.end <= $0.end
            }
            guard liveCrossing else { throw fail }
        }
        try protectGoals(original, updated, cutoff: cutoff, calendar: calendar)
        let todayKey = SleepPlan.dayKey(cutoff, calendar: calendar)
        func legacyMarkers(_ j: Journal) -> [String] {
            let ordinary = (j.sleepReminders?.completions ?? []).filter { $0.day < todayKey }.map { $0.day + ":" + $0.reminder.rawValue }
            let initial = (j.sleepReminders?.initialCompletions ?? []).filter { $0.day < todayKey }.map { "initial:" + $0.day + ":" + $0.reminder.rawValue }
            return (ordinary + initial).sorted()
        }
        guard legacyMarkers(original) == legacyMarkers(updated) else { throw fail }
    }

    private struct Target: Equatable { let minutes: Int; let direction: String }
    private static func protectGoals(_ original: Journal, _ updated: Journal, cutoff: Date, calendar: Calendar) throws {
        // Compare historical targets rather than version IDs: splitting a legacy
        // range to edit today is valid when all older days retain their targets.
        var before = original, after = updated
        before.preferences.timezone = calendar.timeZone.identifier; after.preferences.timezone = calendar.timeZone.identifier
        for daily in [true, false] {
            let component: Calendar.Component = daily ? .day : .weekOfYear
            let boundary = daily ? cutoff : calendar.dateInterval(of: .weekOfYear, for: cutoff)!.start
            var samples: Set<Date> = []
            for goal in (original.goals + updated.goals) where goal.isDaily == daily {
                for date in [goal.effectiveFrom, goal.effectiveUntil].compactMap({ $0 }) where date < boundary {
                    let start = calendar.dateInterval(of: component, for: date)!.start
                    samples.insert(start)
                    if let next = calendar.date(byAdding: daily ? .day : .weekOfYear, value: 1, to: start), next < boundary { samples.insert(next) }
                }
            }
            func targets(_ j: Journal, at date: Date) -> [UUID: Target] {
                let goals = daily ? GoalReports.dailyGoals(j, at: date) : GoalReports.weeklyGoals(j, at: date)
                return Dictionary(uniqueKeysWithValues: goals.map { ($0.activityID, Target(minutes: $0.minutes, direction: $0.direction)) })
            }
            for date in samples where targets(before, at: date) != targets(after, at: date) {
                throw JournalError.invalid(message)
            }
        }
    }
}

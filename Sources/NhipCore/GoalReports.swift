import Foundation

public struct GoalProgress {
    public var seconds: Double
    public var targetSeconds: Double
    public var isComplete: Bool
    public var fraction: Double { targetSeconds > 0 ? min(1, max(0, seconds / targetSeconds)) : 0 }
}

public struct GoalCompletionCount {
    public var completed = 0
    public var total = 0
    public var rate: Double? { total > 0 ? Double(completed) / Double(total) : nil }
}

public struct GoalCompletionSummary {
    public var daily = GoalCompletionCount()
    public var weekly = GoalCompletionCount()
}

public enum GoalReports {
    /// Count recurring goal occurrences, rather than just distinct goal definitions.
    /// Uses the goals still present in the journal and their saved weekly versions.
    public static func completionSummary(_ j: Journal, now: Date = Date()) -> GoalCompletionSummary {
        var result = GoalCompletionSummary()
        let calendar = j.preferences.calendar
        let entries = j.entries.filter { $0.start < now }.sorted { $0.start < $1.start }
        for daily in [true, false] {
            let goals = j.goals.filter { $0.isDaily == daily && $0.direction != "observe" }
            guard let first = goals.map(\.effectiveFrom).min(), first <= now else { continue }
            let component: Calendar.Component = daily ? .day : .weekOfYear
            var start = calendar.dateInterval(of: component, for: first)!.start
            var index = 0
            while start <= now {
                let range = calendar.dateInterval(of: component, for: start)!
                while index < entries.count && entries[index].end <= start { index += 1 }
                var seconds: [UUID: Double] = [:]
                var scan = index
                while scan < entries.count && entries[scan].start < min(range.end, now) {
                    let entry = entries[scan]
                    seconds[entry.activityID, default: 0] += overlap(entry.start, entry.end, start, min(range.end, now))
                    scan += 1
                }
                let applicable = daily ? dailyGoals(j, at: start) : weeklyGoals(j, at: start)
                for goal in applicable where goal.direction != "observe" {
                    let complete = isComplete(goal, seconds: seconds[goal.activityID, default: 0], range: range, now: now)
                    if daily { result.daily.total += 1; if complete { result.daily.completed += 1 } }
                    else { result.weekly.total += 1; if complete { result.weekly.completed += 1 } }
                }
                start = range.end
            }
        }
        if SleepPlan.isEnabled(j) {
            // Older journals have no activation date. Start at the first sleep-goal
            // evidence, never at unrelated historical work entries. With no evidence,
            // only today's four tasks are known to exist.
            let keys = (j.sleepHistory?.sessions.map(\.goalDay) ?? []) + (j.sleepReminders?.completions.map(\.day) ?? [])
            let first = j.sleepReminders?.statisticsStartDay.flatMap { SleepTracking.date($0, calendar: calendar) }
                ?? keys.compactMap { SleepTracking.date($0, calendar: calendar) }.min() ?? now
            let firstDay = calendar.startOfDay(for: first), today = calendar.startOfDay(for: now)
            let days = max(0, (calendar.dateComponents([.day], from: firstDay, to: today).day ?? 0) + 1)
            result.daily.total += days * SleepReminder.allCases.count
            // Index each actual marker once. Actual late markers override legacy
            // checkmarks, just as SleepPlan.isComplete does on the daily page.
            var actual: [String: Bool] = [:]
            for session in j.sleepHistory?.sessions ?? [] {
                let bed = session.goalDay + ":" + session.kind.bedtime.rawValue
                actual[bed] = actual[bed, default: false] || session.isOnTime(session.kind.bedtime)
                if session.end != nil {
                    let wake = session.wakeGoalDay + ":" + session.kind.wake.rawValue
                    actual[wake] = actual[wake, default: false] || session.isOnTime(session.kind.wake)
                }
            }
            for completion in j.sleepReminders?.completions ?? [] {
                let key = completion.day + ":" + completion.reminder.rawValue
                if actual[key] == nil { actual[key] = true }
            }
            let firstKey = SleepPlan.dayKey(firstDay, calendar: calendar), lastKey = SleepPlan.dayKey(today, calendar: calendar)
            result.daily.completed += actual.filter { key, complete in
                let day = String(key.prefix(10))
                return complete && day >= firstKey && day <= lastKey
            }.count
        }
        return result
    }
    private static func isComplete(_ goal: Goal, seconds: Double, range: DateInterval, now: Date) -> Bool {
        let active = now >= range.start && goal.effectiveFrom < range.end
        let target = Double(goal.minutes) * 60
        switch goal.direction {
        case "increase": return active && target > 0 && seconds >= target
        case "limit": return active && now >= range.end && seconds <= target
        default: return false
        }
    }
    public static func dailyGoals(_ j: Journal, at date: Date) -> [Goal] {
        let end = j.preferences.calendar.dateInterval(of: .day, for: date)!.end
        return j.goals.filter { $0.isDaily && $0.effectiveFrom < end }
    }
    public static func weeklyGoals(_ j: Journal, at date: Date) -> [Goal] {
        let end = j.preferences.calendar.dateInterval(of: .weekOfYear, for: date)!.end
        var latest: [UUID: Goal] = [:]
        for goal in j.goals where !goal.isDaily && goal.effectiveFrom < end {
            if latest[goal.activityID].map({ $0.effectiveFrom <= goal.effectiveFrom }) ?? true { latest[goal.activityID] = goal }
        }
        return j.activities.compactMap { latest[$0.id] }
    }
    public static func saveWeeklyGoal(_ j: inout Journal, activityID: UUID, minutes: Int, at date: Date) throws {
        guard j.activity(activityID) != nil, (1...10080).contains(minutes) else {
            throw JournalError.invalid("Mục tiêu tuần phải từ 1 phút đến 168 giờ và có hoạt động hợp lệ.")
        }
        let range = j.preferences.calendar.dateInterval(of: .weekOfYear, for: date)!
        let candidates = j.goals.indices.filter {
            !j.goals[$0].isDaily && j.goals[$0].activityID == activityID && range.contains(j.goals[$0].effectiveFrom) && j.goals[$0].effectiveFrom < range.end
        }
        let existing = candidates.max { left, right in
            let a = j.goals[left].effectiveFrom, b = j.goals[right].effectiveFrom
            return a == b ? left < right : a < b
        }
        if let index = existing {
            j.goals[index].minutes = minutes; j.goals[index].direction = "increase"
        } else {
            j.goals.append(Goal(activityID: activityID, direction: "increase", minutes: minutes, effectiveFrom: range.start, period: "week"))
        }
    }
    public static func progress(_ goal: Goal, journal: Journal, at date: Date, now: Date = Date()) -> GoalProgress {
        let range = journal.preferences.calendar.dateInterval(of: goal.isDaily ? .day : .weekOfYear, for: date)!
        let seconds = journal.entries.filter { $0.activityID == goal.activityID }.reduce(0) {
            $0 + overlap($1.start, $1.end, range.start, range.end)
        }
        let target = Double(goal.minutes) * 60
        let complete = isComplete(goal, seconds: seconds, range: range, now: now)
        return GoalProgress(seconds: seconds, targetSeconds: target, isComplete: complete)
    }
    public static func saveDailyGoal(_ j: inout Journal, activityID: UUID, minutes: Int, at date: Date) throws {
        guard j.activity(activityID) != nil, (1...1440).contains(minutes) else {
            throw JournalError.invalid("Mục tiêu mỗi ngày phải từ 1 phút đến 24 giờ và có hoạt động hợp lệ.")
        }
        if let index = j.goals.firstIndex(where: { $0.isDaily && $0.activityID == activityID }) {
            j.goals[index].minutes = minutes; j.goals[index].direction = "increase"
        } else {
            j.goals.append(Goal(activityID: activityID, direction: "increase", minutes: minutes, effectiveFrom: j.preferences.calendar.startOfDay(for: date), period: "day"))
        }
    }
    @discardableResult public static func deleteGoal(_ j: inout Journal, id: UUID) -> [Goal] {
        guard let goal = j.goals.first(where: { $0.id == id }) else { return [] }
        let removed = j.goals.filter { $0.activityID == goal.activityID && $0.periodName == goal.periodName }
        j.goals.removeAll { $0.activityID == goal.activityID && $0.periodName == goal.periodName }
        return removed
    }
    public static func restoreGoals(_ j: inout Journal, goals: [Goal]) throws {
        var draft = j
        let ids = Set(draft.goals.map(\.id))
        draft.goals += goals.filter { !ids.contains($0.id) }
        try Engine.validate(draft)
        j = draft
    }
}

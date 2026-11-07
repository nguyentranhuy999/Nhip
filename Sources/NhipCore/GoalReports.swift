import Foundation

public struct GoalProgress {
    public var seconds: Double
    public var targetSeconds: Double
    public var isComplete: Bool
    public var fraction: Double { targetSeconds > 0 ? min(1, max(0, seconds / targetSeconds)) : 0 }
}

public enum GoalReports {
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
        let active = now >= range.start && goal.effectiveFrom < range.end
        let complete: Bool
        switch goal.direction {
        case "increase": complete = active && target > 0 && seconds >= target
        case "limit": complete = active && now >= range.end && seconds <= target
        default: complete = false
        }
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

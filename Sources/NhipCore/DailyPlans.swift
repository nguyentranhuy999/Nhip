import Foundation

/// A reversible change to one day's goals, including any split legacy versions.
public struct DailyPlanChange: Equatable {
    public var before: [Goal]
    public var after: [Goal]
}

extension GoalReports {
    /// Stop old indefinite daily rules after today without changing past occurrences.
    /// New plans always have an explicit end, so this is naturally idempotent.
    public static func prepareDailyPlans(_ j: inout Journal, at now: Date = Date()) {
        for index in j.goals.indices where j.goals[index].isDaily && j.goals[index].effectiveUntil == nil {
            let lastDay = max(now, j.goals[index].effectiveFrom)
            j.goals[index].effectiveUntil = j.preferences.calendar.dateInterval(of: .day, for: lastDay)!.end
        }
    }

    /// Set a target for exactly the selected local calendar day.
    public static func saveDailyPlan(_ j: inout Journal, activityID: UUID, minutes: Int, on date: Date) throws {
        guard j.activity(activityID) != nil, (1...1440).contains(minutes) else {
            throw JournalError.invalid("Nhiệm vụ trong ngày phải từ 1 phút đến 24 giờ và có hoạt động hợp lệ.")
        }
        _ = try replaceDailyPlan(&j, activityID: activityID, minutes: minutes, on: date)
    }

    /// Remove only this day, retaining all other days of an older recurring rule.
    public static func deleteDailyPlan(_ j: inout Journal, id: UUID, on date: Date) throws -> DailyPlanChange? {
        guard let goal = dailyGoals(j, at: date).first(where: { $0.id == id }) else { return nil }
        return try replaceDailyPlan(&j, activityID: goal.activityID, minutes: nil, on: date)
    }

    public static func restoreDailyPlan(_ j: inout Journal, change: DailyPlanChange) throws {
        let beforeIDs = Set(change.before.map(\.id))
        // Repeated undo is harmless, while later edits must never be overwritten.
        if change.before.allSatisfy({ j.goals.contains($0) })
            && change.after.filter({ !beforeIDs.contains($0.id) }).allSatisfy({ after in !j.goals.contains(where: { $0.id == after.id }) }) { return }
        guard change.after.allSatisfy({ j.goals.contains($0) }) else {
            throw JournalError.invalid("Nhiệm vụ đã thay đổi sau khi xoá. Không thể hoàn tác đè lên thay đổi mới.")
        }
        var draft = j
        let afterIDs = Set(change.after.map(\.id))
        draft.goals.removeAll { afterIDs.contains($0.id) }
        for goal in change.before {
            guard !draft.goals.contains(where: { $0.id == goal.id }) else {
                throw JournalError.invalid("Nhiệm vụ đã thay đổi sau khi xoá. Không thể hoàn tác đè lên thay đổi mới.")
            }
            draft.goals.append(goal)
        }
        try Engine.validate(draft)
        j = draft
    }

    private static func replaceDailyPlan(_ j: inout Journal, activityID: UUID, minutes: Int?, on date: Date) throws -> DailyPlanChange {
        let range = j.preferences.calendar.dateInterval(of: .day, for: date)!
        let before = j.goals.filter {
            $0.isDaily && $0.activityID == activityID && $0.effectiveFrom < range.end
                && ($0.effectiveUntil.map { $0 > range.start } ?? true)
        }
        var after: [Goal] = []
        for goal in before {
            if goal.effectiveFrom < range.start {
                var prefix = goal; prefix.effectiveUntil = range.start
                after.append(prefix)
            }
            if goal.effectiveUntil.map({ $0 > range.end }) ?? true {
                var suffix = goal; suffix.id = UUID(); suffix.effectiveFrom = range.end
                after.append(suffix)
            }
        }
        if let minutes {
            var target = before.first { $0.effectiveFrom == range.start && $0.effectiveUntil == range.end }
                ?? Goal(activityID: activityID, direction: "increase", minutes: minutes, effectiveFrom: range.start, period: "day", effectiveUntil: range.end)
            target.minutes = minutes; target.direction = "increase"
            after.append(target)
        }
        var draft = j
        let ids = Set(before.map(\.id))
        draft.goals.removeAll { ids.contains($0.id) }
        draft.goals += after
        try Engine.validate(draft)
        j = draft
        return DailyPlanChange(before: before, after: after)
    }
}

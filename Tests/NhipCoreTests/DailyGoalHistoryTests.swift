import Foundation
import NhipCore

final class DailyGoalHistoryTests {
    func at(_ value: String) -> Date { ISO8601DateFormatter().date(from: value + "+07:00")! }
    func journal() -> Journal { var j = legacyJournal(); SleepPlan.setEnabled(false, journal: &j); return j }
    let first = "2025-11-03T12:00:00"
    let second = "2025-11-04T12:00:00"
    let third = "2025-11-05T12:00:00"
    func record(_ j: inout Journal, date: String, minutes: Int = 30) throws {
        let start = at(date)
        try Engine.record(&j, entry: Entry(start: start, end: start.addingTimeInterval(Double(minutes * 60)), activityID: j.activities[0].id))
    }
    func testDeletingTodayKeepsPastCompletionsAndRates() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: at(first))
        try record(&j, date: "2025-11-03T08:00:00")
        try record(&j, date: "2025-11-04T08:00:00")
        let before = j, goal = j.goals[0]
        let removed = GoalReports.deleteGoal(&j, id: goal.id, at: at(third))
        XCTAssertEqual(removed, [goal]); XCTAssertEqual(j.entries, before.entries)
        XCTAssertEqual(j.goals[0].effectiveUntil, j.preferences.calendar.startOfDay(for: at(third)))
        XCTAssertTrue(GoalReports.dailyGoals(j, at: at(third)).isEmpty)
        XCTAssertTrue(GoalReports.dailyGoals(j, at: at("2025-12-01T12:00:00")).isEmpty)
        let summary = GoalReports.completionSummary(j, now: at(third))
        XCTAssertEqual(summary.daily.completed, 2); XCTAssertEqual(summary.daily.total, 2)
        XCTAssertEqual(summary.daily.rate!, 1)
        try GoalReports.saveDailyGoal(&j, activityID: j.activities[1].id, minutes: 60, at: at(third))
        let replacement = GoalReports.completionSummary(j, now: at(third))
        XCTAssertEqual(replacement.daily.completed, 2); XCTAssertEqual(replacement.daily.total, 3)
        try Engine.validate(j)
    }
    func testEditingTargetsCreatesDailyVersions() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: at(first))
        try record(&j, date: "2025-11-03T08:00:00")
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 60, at: at(second))
        try record(&j, date: "2025-11-04T08:00:00")
        let old = GoalReports.dailyGoals(j, at: at(first))[0]
        let today = GoalReports.dailyGoals(j, at: at(second))[0]
        XCTAssertEqual(old.minutes, 30); XCTAssertEqual(today.minutes, 60)
        XCTAssertTrue(old.id != today.id)
        XCTAssertEqual(GoalReports.completionSummary(j, now: at(second)).daily.completed, 1)
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 20, at: at(second))
        XCTAssertEqual(j.goals.count, 2)
        XCTAssertEqual(GoalReports.dailyGoals(j, at: at(second))[0].id, today.id)
        XCTAssertEqual(GoalReports.dailyGoals(j, at: at(first))[0], old)
        XCTAssertEqual(GoalReports.completionSummary(j, now: at(second)).daily.completed, 2)
        try Engine.validate(j)
    }
    func testUndoReopensEndedVersionAndRejectsConflictingReplacement() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: at(first))
        let before = j
        let undo = GoalReports.deleteGoal(&j, id: j.goals[0].id, at: at(second))
        try GoalReports.restoreGoals(&j, goals: undo)
        XCTAssertEqual(j, before)
        try GoalReports.restoreGoals(&j, goals: undo)
        XCTAssertEqual(j, before)
        _ = GoalReports.deleteGoal(&j, id: j.goals[0].id, at: at(second))
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 60, at: at(second))
        let replacement = j
        XCTAssertThrowsError(try GoalReports.restoreGoals(&j, goals: undo))
        XCTAssertEqual(j, replacement)
    }
    func testSameDayDeletionAndUndoKeepOldVersionsEnded() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: at(first))
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 60, at: at(second))
        let old = j.goals[0], today = GoalReports.dailyGoals(j, at: at(second))[0]
        let undo = GoalReports.deleteGoal(&j, id: today.id, at: at(second))
        XCTAssertEqual(j.goals, [old]); XCTAssertTrue(GoalReports.dailyGoals(j, at: at(second)).isEmpty)
        XCTAssertEqual(GoalReports.dailyGoals(j, at: at(first))[0].minutes, 30)
        try GoalReports.restoreGoals(&j, goals: undo)
        XCTAssertEqual(GoalReports.dailyGoals(j, at: at(second))[0], today)
        XCTAssertEqual(j.goals[0], old)
        try Engine.validate(j)
    }
    func testReaddingAfterGapDoesNotBackfillDeletedDays() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: at(first))
        try record(&j, date: "2025-11-03T08:00:00")
        _ = GoalReports.deleteGoal(&j, id: j.goals[0].id, at: at(second))
        try record(&j, date: "2025-11-04T08:00:00", minutes: 60)
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 60, at: at(third))
        XCTAssertTrue(GoalReports.dailyGoals(j, at: at(second)).isEmpty)
        XCTAssertEqual(GoalReports.dailyGoals(j, at: at(third))[0].minutes, 60)
        let summary = GoalReports.completionSummary(j, now: at(third))
        XCTAssertEqual(summary.daily.completed, 1); XCTAssertEqual(summary.daily.total, 2)
        XCTAssertEqual(summary.daily.rate!, 0.5)
        XCTAssertEqual(GoalReports.dailyGoals(j, at: at("2025-11-06T12:00:00"))[0].minutes, 60)
        try Engine.validate(j)
    }
    func testVersionsRoundTripAndLegacyGoalsRemainCompatible() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: at(first))
        try record(&j, date: "2025-11-03T08:00:00")
        // Old JSON contains no effectiveUntil. Its recurring rule still loads unchanged.
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(j)) as! [String: Any]
        var goals = object["goals"] as! [[String: Any]]
        goals[0].removeValue(forKey: "effectiveUntil"); object["goals"] = goals
        j = try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(j.goals[0].effectiveUntil)
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 60, at: at(second))
        _ = GoalReports.deleteGoal(&j, id: GoalReports.dailyGoals(j, at: at(second))[0].id, at: at(third))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try Repository(url: directory.appendingPathComponent("daily-history.sqlite"))
        try repository.save(j)
        let loaded = try repository.load()
        XCTAssertEqual(loaded, j)
        XCTAssertEqual(try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j)), j)
        XCTAssertTrue(GoalReports.dailyGoals(loaded, at: at(third)).isEmpty)
        XCTAssertEqual(GoalReports.dailyGoals(loaded, at: at(first))[0].minutes, 30)
        let summary = GoalReports.completionSummary(loaded, now: at(third))
        XCTAssertEqual(summary.daily.completed, 1); XCTAssertEqual(summary.daily.total, 2)
    }
    func testLocalMidnightAndDSTDeletion() throws {
        var j = journal(); j.preferences.timezone = "America/New_York"
        let formatter = ISO8601DateFormatter()
        let firstDay = formatter.date(from: "2025-11-02T12:00:00-05:00")!
        let nextDay = formatter.date(from: "2025-11-03T00:01:00-05:00")!
        let range = j.preferences.calendar.dateInterval(of: .day, for: firstDay)!
        XCTAssertEqual(range.duration, 25 * 3600)
        try GoalReports.saveDailyGoal(&j, activityID: j.activities[0].id, minutes: 30, at: firstDay)
        try Engine.record(&j, entry: Entry(start: range.end.addingTimeInterval(-1800), end: range.end, activityID: j.activities[0].id))
        _ = GoalReports.deleteGoal(&j, id: j.goals[0].id, at: nextDay)
        XCTAssertEqual(j.goals[0].effectiveUntil, range.end)
        XCTAssertEqual(GoalReports.dailyGoals(j, at: range.end.addingTimeInterval(-1)).count, 1)
        XCTAssertTrue(GoalReports.dailyGoals(j, at: range.end).isEmpty)
        let summary = GoalReports.completionSummary(j, now: nextDay)
        XCTAssertEqual(summary.daily.completed, 1); XCTAssertEqual(summary.daily.total, 1)
        try Engine.validate(j)
    }
    func testValidationRejectsOverlapsAndInvalidEnds() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: at(first))
        j.goals[0].effectiveUntil = j.preferences.calendar.startOfDay(for: at(second))
        j.goals.append(Goal(activityID: id, direction: "increase", minutes: 60, effectiveFrom: j.goals[0].effectiveUntil!, period: "day"))
        try Engine.validate(j)
        let valid = j
        j.goals[0].effectiveUntil = nil
        XCTAssertThrowsError(try Engine.validate(j))
        j = valid; j.goals[0].effectiveUntil = j.goals[1].effectiveFrom.addingTimeInterval(1)
        XCTAssertThrowsError(try Engine.validate(j))
        j = valid; j.goals[0].effectiveUntil = j.goals[0].effectiveFrom
        XCTAssertThrowsError(try Engine.validate(j))
        j = valid; j.goals[0].effectiveUntil = Date(timeIntervalSince1970: .infinity)
        XCTAssertThrowsError(try Engine.validate(j))
        j = valid; j.goals[0].period = "week"
        XCTAssertThrowsError(try Engine.validate(j))
    }
    func testEndedVersionIsInactiveOutsideItsLifetime() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: at(first))
        try record(&j, date: "2025-11-03T08:00:00")
        try record(&j, date: "2025-11-04T08:00:00")
        _ = GoalReports.deleteGoal(&j, id: j.goals[0].id, at: at(second))
        let ended = j.goals[0]
        XCTAssertTrue(GoalReports.progress(ended, journal: j, at: at(first), now: at(second)).isComplete)
        XCTAssertFalse(GoalReports.progress(ended, journal: j, at: at(second), now: at(second)).isComplete)
    }
    func testStaleDeleteIsNoopAndOtherDataIsUntouched() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: at(first))
        try GoalReports.saveDailyGoal(&j, activityID: j.activities[1].id, minutes: 60, at: at(first))
        try GoalReports.saveWeeklyGoal(&j, activityID: id, minutes: 120, at: at(first))
        try record(&j, date: "2025-11-03T08:00:00")
        let otherGoal = j.goals[1], weekly = j.goals[2], entries = j.entries, activities = j.activities
        let oldID = j.goals[0].id
        _ = GoalReports.deleteGoal(&j, id: oldID, at: at(second))
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 90, at: at(third))
        let beforeStaleDelete = j
        XCTAssertTrue(GoalReports.deleteGoal(&j, id: oldID, at: at(third)).isEmpty)
        XCTAssertEqual(j, beforeStaleDelete)
        XCTAssertEqual(j.goals[1], otherGoal); XCTAssertEqual(j.goals[2], weekly)
        XCTAssertEqual(j.entries, entries); XCTAssertEqual(j.activities, activities)
        try Engine.validate(j)
    }
}

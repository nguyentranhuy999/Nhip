import Foundation
import NhipCore

final class DailyPlanTests {
    func at(_ day: Int, hour: Int = 12) -> Date {
        ISO8601DateFormatter().date(from: String(format: "2025-11-%02dT%02d:00:00+07:00", day, hour))!
    }
    func journal() -> Journal { var j = legacyJournal(); SleepPlan.setEnabled(false, journal: &j); return j }
    func record(_ j: inout Journal, day: Int, minutes: Int) throws {
        let start = at(day, hour: 8)
        try Engine.record(&j, entry: Entry(start: start, end: start.addingTimeInterval(Double(minutes * 60)), activityID: j.activities[0].id))
    }
    func plan(_ j: Journal, day: Int) -> Goal? { GoalReports.dailyGoals(j, at: at(day)).first { $0.activityID == j.activities[0].id } }

    func testIndependentDatesMatchUserExample() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 120, on: at(3))
        try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 180, on: at(4))
        try record(&j, day: 3, minutes: 120)
        try record(&j, day: 4, minutes: 180)
        XCTAssertEqual(plan(j, day: 3)?.minutes, 120); XCTAssertEqual(plan(j, day: 4)?.minutes, 180)
        XCTAssertNil(plan(j, day: 5)); XCTAssertNil(plan(j, day: 6))
        let summary = GoalReports.completionSummary(j, now: at(5))
        XCTAssertEqual(summary.daily.completed, 2); XCTAssertEqual(summary.daily.total, 2)
        XCTAssertEqual(summary.daily.rate!, 1)
        XCTAssertEqual(Reports.summarize(j, range: Reports.allTimeRange(j)).total, 5 * 3600)
    }
    func testFuturePlansAreExcludedUntilTheirDay() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 120, on: at(3))
        try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 180, on: at(5))
        try record(&j, day: 3, minutes: 120)
        let now = GoalReports.completionSummary(j, now: at(3))
        XCTAssertEqual(now.daily.completed, 1); XCTAssertEqual(now.daily.total, 1)
        XCTAssertNil(plan(j, day: 4))
        let due = GoalReports.completionSummary(j, now: at(5))
        XCTAssertEqual(due.daily.completed, 1); XCTAssertEqual(due.daily.total, 2)
        let later = GoalReports.completionSummary(j, now: at(9))
        XCTAssertEqual(later.daily.total, 2)
    }
    func testChangingOneDateKeepsNeighborsAndActivities() throws {
        var j = journal(); let id = j.activities[0].id
        for day in 3...5 { try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 120, on: at(day)) }
        try GoalReports.saveDailyPlan(&j, activityID: j.activities[1].id, minutes: 60, on: at(4))
        let first = plan(j, day: 3), last = plan(j, day: 5), other = GoalReports.dailyGoals(j, at: at(4))[1]
        let activities = j.activities
        try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 180, on: at(4))
        XCTAssertEqual(plan(j, day: 3), first); XCTAssertEqual(plan(j, day: 5), last)
        XCTAssertEqual(plan(j, day: 4)?.minutes, 180)
        XCTAssertEqual(GoalReports.dailyGoals(j, at: at(4))[1], other)
        XCTAssertEqual(j.activities, activities)
        try Engine.validate(j)
    }
    func testDeletingOneDateKeepsNeighborsAndTotals() throws {
        var j = journal(); let id = j.activities[0].id
        for day in 3...5 {
            try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 120, on: at(day))
            try record(&j, day: day, minutes: 120)
        }
        let first = plan(j, day: 3), last = plan(j, day: 5), entries = j.entries
        _ = try GoalReports.deleteDailyPlan(&j, id: plan(j, day: 4)!.id, on: at(4))
        XCTAssertNil(plan(j, day: 4)); XCTAssertEqual(plan(j, day: 3), first); XCTAssertEqual(plan(j, day: 5), last)
        XCTAssertEqual(j.entries, entries)
        let summary = GoalReports.completionSummary(j, now: at(6))
        XCTAssertEqual(summary.daily.total, 2); XCTAssertEqual(summary.daily.completed, 2)
        XCTAssertEqual(Reports.summarize(j, range: Reports.allTimeRange(j)).total, 6 * 3600)
    }
    func testLegacyPreparationPreservesHistoryAndStopsRepetition() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 120, at: at(3))
        try GoalReports.saveWeeklyGoal(&j, activityID: id, minutes: 600, at: at(3))
        try record(&j, day: 3, minutes: 120)
        let before = GoalReports.completionSummary(j, now: at(4)), weekly = j.goals[1], entries = j.entries
        GoalReports.prepareDailyPlans(&j, at: at(4))
        let after = GoalReports.completionSummary(j, now: at(4))
        XCTAssertEqual(before.daily.total, after.daily.total); XCTAssertEqual(before.daily.completed, after.daily.completed)
        XCTAssertEqual(j.goals[1], weekly); XCTAssertEqual(j.entries, entries)
        XCTAssertEqual(plan(j, day: 3)?.minutes, 120); XCTAssertEqual(plan(j, day: 4)?.minutes, 120)
        XCTAssertNil(plan(j, day: 5))
        let once = j; GoalReports.prepareDailyPlans(&j, at: at(9)); XCTAssertEqual(j, once)
        let futureGoal = Goal(activityID: j.activities[1].id, direction: "increase", minutes: 60, effectiveFrom: j.preferences.calendar.startOfDay(for: at(8)), period: "day")
        j.goals.append(futureGoal); GoalReports.prepareDailyPlans(&j, at: at(4))
        XCTAssertEqual(GoalReports.dailyGoals(j, at: at(8)).count, 1)
        XCTAssertTrue(GoalReports.dailyGoals(j, at: at(9)).isEmpty)
        try Engine.validate(j)
    }
    func testEditingInsideLegacyRangeOnlySplitsSelectedDay() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 120, at: at(3))
        GoalReports.prepareDailyPlans(&j, at: at(6))
        try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 180, on: at(4))
        XCTAssertEqual(plan(j, day: 3)?.minutes, 120); XCTAssertEqual(plan(j, day: 4)?.minutes, 180)
        XCTAssertEqual(plan(j, day: 5)?.minutes, 120); XCTAssertEqual(plan(j, day: 6)?.minutes, 120)
        XCTAssertNil(plan(j, day: 7)); XCTAssertEqual(j.goals.count, 3)
        try Engine.validate(j)
    }
    func testDeletingInsideLegacyRangeAndUndo() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 120, at: at(3))
        GoalReports.prepareDailyPlans(&j, at: at(6))
        let before = j
        let change = try GoalReports.deleteDailyPlan(&j, id: plan(j, day: 4)!.id, on: at(4))!
        XCTAssertNil(plan(j, day: 4)); XCTAssertEqual(plan(j, day: 3)?.minutes, 120)
        XCTAssertEqual(plan(j, day: 5)?.minutes, 120); XCTAssertEqual(plan(j, day: 6)?.minutes, 120)
        try GoalReports.restoreDailyPlan(&j, change: change)
        XCTAssertEqual(j, before)
        try GoalReports.restoreDailyPlan(&j, change: change)
        XCTAssertEqual(j, before)
    }
    func testUndoRejectsLaterEditsAndConflictingReplacement() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 120, at: at(3))
        GoalReports.prepareDailyPlans(&j, at: at(6))
        let change = try GoalReports.deleteDailyPlan(&j, id: plan(j, day: 4)!.id, on: at(4))!
        j.goals[0].minutes = 90
        let edited = j
        XCTAssertThrowsError(try GoalReports.restoreDailyPlan(&j, change: change)); XCTAssertEqual(j, edited)
        j = journal()
        try GoalReports.saveDailyPlan(&j, activityID: j.activities[0].id, minutes: 120, on: at(4))
        let simple = try GoalReports.deleteDailyPlan(&j, id: plan(j, day: 4)!.id, on: at(4))!
        try GoalReports.saveDailyPlan(&j, activityID: j.activities[0].id, minutes: 180, on: at(4))
        let replacement = j
        XCTAssertThrowsError(try GoalReports.restoreDailyPlan(&j, change: simple)); XCTAssertEqual(j, replacement)
    }
    func testIndependentPlansAndUndoRoundTrip() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 120, on: at(3))
        try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 180, on: at(5))
        try record(&j, day: 3, minutes: 120)
        let before = j
        let undo = try GoalReports.deleteDailyPlan(&j, id: plan(j, day: 5)!.id, on: at(5))!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try Repository(url: directory.appendingPathComponent("daily-plans.sqlite"))
        try repository.save(j); var loaded = try repository.load()
        XCTAssertEqual(loaded, j); XCTAssertNil(plan(loaded, day: 5))
        try GoalReports.restoreDailyPlan(&loaded, change: undo)
        XCTAssertEqual(loaded, before)
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(loaded))
        XCTAssertEqual(decoded, loaded)
        XCTAssertNil(plan(decoded, day: 4)); XCTAssertNil(plan(decoded, day: 6))
        XCTAssertEqual(GoalReports.completionSummary(decoded, now: at(6)).daily.completed, 1)
    }
    func testDayBoundariesRespectTimezoneDSTAndNewYear() throws {
        let formatter = ISO8601DateFormatter()
        for (timestamp, hours) in [("2025-03-09T12:00:00-04:00", 23), ("2025-11-02T12:00:00-05:00", 25), ("2025-12-31T12:00:00-05:00", 24)] {
            var j = journal(); j.preferences.timezone = "America/New_York"
            let date = formatter.date(from: timestamp)!, id = j.activities[0].id
            try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 30, on: date)
            let range = j.preferences.calendar.dateInterval(of: .day, for: date)!
            XCTAssertEqual(range.duration, Double(hours * 3600))
            XCTAssertEqual(j.goals[0].effectiveUntil, range.end)
            XCTAssertTrue(GoalReports.dailyGoals(j, at: range.start.addingTimeInterval(-1)).isEmpty)
            XCTAssertEqual(GoalReports.dailyGoals(j, at: range.end.addingTimeInterval(-1)).count, 1)
            XCTAssertTrue(GoalReports.dailyGoals(j, at: range.end).isEmpty)
            try Engine.record(&j, entry: Entry(start: range.end.addingTimeInterval(-1800), end: range.end, activityID: id))
            let summary = GoalReports.completionSummary(j, now: range.end.addingTimeInterval(3600))
            XCTAssertEqual(summary.daily.total, 1); XCTAssertEqual(summary.daily.completed, 1)
        }
    }
    func testInvalidTargetsLeaveJournalUnchanged() throws {
        var j = journal(); let id = j.activities[0].id, before = j
        XCTAssertThrowsError(try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 0, on: at(3)))
        XCTAssertThrowsError(try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 1441, on: at(3)))
        XCTAssertThrowsError(try GoalReports.saveDailyPlan(&j, activityID: UUID(), minutes: 120, on: at(3)))
        XCTAssertEqual(j, before)
        XCTAssertNil(try GoalReports.deleteDailyPlan(&j, id: UUID(), on: at(3)))
        XCTAssertEqual(j, before)
    }
    func testRepeatedSaveUpdatesOneDayWithoutDuplicates() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 120, on: at(3))
        let first = j.goals[0]
        try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 180, on: at(3, hour: 18))
        XCTAssertEqual(j.goals.count, 1); XCTAssertEqual(j.goals[0].id, first.id)
        XCTAssertEqual(j.goals[0].minutes, 180)
        XCTAssertEqual(j.goals[0].effectiveFrom, first.effectiveFrom)
        XCTAssertEqual(j.goals[0].effectiveUntil, first.effectiveUntil)
        GoalReports.prepareDailyPlans(&j, at: at(5)); XCTAssertNil(plan(j, day: 4))
        try Engine.validate(j)
    }
    func testPastEditsOnlyRecalculateSelectedDate() throws {
        var j = journal(); let id = j.activities[0].id
        for day in 3...4 {
            try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 120, on: at(day))
            try record(&j, day: day, minutes: 120)
        }
        let today = plan(j, day: 4), entries = j.entries
        XCTAssertEqual(GoalReports.completionSummary(j, now: at(4)).daily.completed, 2)
        try GoalReports.saveDailyPlan(&j, activityID: id, minutes: 180, on: at(3))
        XCTAssertEqual(plan(j, day: 4), today); XCTAssertEqual(j.entries, entries)
        let summary = GoalReports.completionSummary(j, now: at(4))
        XCTAssertEqual(summary.daily.total, 2); XCTAssertEqual(summary.daily.completed, 1)
    }
    func testSleepTasksRemainDailyAndPlanResetIsClean() throws {
        var j = legacyJournal()
        SleepPlan.prepareStatistics(journal: &j, on: at(3))
        try GoalReports.saveDailyPlan(&j, activityID: j.activities[0].id, minutes: 120, on: at(3))
        try record(&j, day: 3, minutes: 120)
        GoalReports.prepareDailyPlans(&j, at: at(4))
        let summary = GoalReports.completionSummary(j, now: at(4))
        XCTAssertEqual(summary.daily.total, 9); XCTAssertEqual(summary.daily.completed, 1)
        XCTAssertTrue(GoalReports.dailyGoals(j, at: at(4)).isEmpty)
        XCTAssertEqual(SleepReminder.allCases.count, 4); XCTAssertTrue(SleepPlan.isEnabled(j))
        j.reset(at: at(4))
        XCTAssertTrue(j.goals.isEmpty)
        XCTAssertEqual(GoalReports.completionSummary(j, now: at(4)).daily.total, 4)
    }
}

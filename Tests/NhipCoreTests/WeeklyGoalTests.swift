import Foundation
import NhipCore

final class WeeklyGoalTests {
    let base = Date(timeIntervalSince1970: 1_735_689_600)
    func at(_ minute: Double) -> Date { base.addingTimeInterval(minute * 60) }
    func testWeeklyGoalVersionsPreservePastWeeksAndDailyGoal() throws {
        var j = Journal(); let id = j.activities[0].id, c = j.preferences.calendar
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: base)
        let dailyID = j.goals[0].id
        try GoalReports.saveWeeklyGoal(&j, activityID: id, minutes: 180, at: base)
        let first = GoalReports.weeklyGoals(j, at: base)[0]
        let start = c.dateInterval(of: .weekOfYear, for: base)!.start
        XCTAssertEqual(first.effectiveFrom, start)
        try GoalReports.saveWeeklyGoal(&j, activityID: id, minutes: 300, at: at(1440))
        XCTAssertEqual(GoalReports.weeklyGoals(j, at: start)[0].id, first.id)
        XCTAssertEqual(GoalReports.weeklyGoals(j, at: base)[0].minutes, 300)
        let nextWeek = c.date(byAdding: .weekOfYear, value: 1, to: start)!
        try GoalReports.saveWeeklyGoal(&j, activityID: id, minutes: 360, at: nextWeek)
        XCTAssertEqual(GoalReports.weeklyGoals(j, at: base)[0].minutes, 300)
        XCTAssertEqual(GoalReports.weeklyGoals(j, at: nextWeek)[0].minutes, 360)
        XCTAssertEqual(GoalReports.dailyGoals(j, at: base)[0].id, dailyID)
        XCTAssertEqual(GoalReports.dailyGoals(j, at: base)[0].minutes, 30)
        XCTAssertEqual(j.goals.count, 3); try Engine.validate(j)
    }
    func testWeeklyProgressAggregatesDaysAndResetsMonday() throws {
        var j = Journal(); let id = j.activities[0].id, c = j.preferences.calendar
        try GoalReports.saveWeeklyGoal(&j, activityID: id, minutes: 60, at: base)
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 60, at: base)
        try Engine.record(&j, entry: Entry(start: base, end: at(30), activityID: id))
        try Engine.record(&j, entry: Entry(start: at(1440), end: at(1470), activityID: id))
        try Engine.record(&j, entry: Entry(start: at(2880), end: at(2940), activityID: j.activities[1].id))
        let goal = GoalReports.weeklyGoals(j, at: base)[0]
        let progress = GoalReports.progress(goal, journal: j, at: base, now: at(2940))
        XCTAssertEqual(progress.seconds, 3600); XCTAssertTrue(progress.isComplete)
        let daily = GoalReports.dailyGoals(j, at: at(1440))[0]
        XCTAssertFalse(GoalReports.progress(daily, journal: j, at: at(1440), now: at(2940)).isComplete)
        let nextWeek = c.dateInterval(of: .weekOfYear, for: base)!.end
        XCTAssertEqual(GoalReports.weeklyGoals(j, at: nextWeek)[0].id, goal.id)
        let reset = GoalReports.progress(goal, journal: j, at: nextWeek, now: nextWeek)
        XCTAssertEqual(reset.seconds, 0); XCTAssertFalse(reset.isComplete)
        XCTAssertEqual(j.entries.count, 3)
    }
    func testWeeklyProgressSplitsSundayAndMonday() throws {
        var j = Journal(); let id = j.activities[0].id
        let week = j.preferences.calendar.dateInterval(of: .weekOfYear, for: base)!
        let monday = week.end
        try GoalReports.saveWeeklyGoal(&j, activityID: id, minutes: 30, at: base)
        try Engine.record(&j, entry: Entry(start: monday.addingTimeInterval(-900), end: monday.addingTimeInterval(900), activityID: id))
        let goal = GoalReports.weeklyGoals(j, at: base)[0]
        let old = GoalReports.progress(goal, journal: j, at: base, now: monday.addingTimeInterval(1800))
        let new = GoalReports.progress(goal, journal: j, at: monday, now: monday.addingTimeInterval(1800))
        XCTAssertEqual(old.seconds, 900); XCTAssertEqual(new.seconds, 900)
        XCTAssertFalse(old.isComplete); XCTAssertFalse(new.isComplete)
        try Engine.record(&j, entry: Entry(start: monday.addingTimeInterval(900), end: monday.addingTimeInterval(1800), activityID: id))
        XCTAssertTrue(GoalReports.progress(goal, journal: j, at: monday, now: monday.addingTimeInterval(1800)).isComplete)
        XCTAssertFalse(GoalReports.progress(goal, journal: j, at: base, now: monday.addingTimeInterval(1800)).isComplete)
    }
    func testWeeklyValidationDeletionAndUndoPreserveActivity() throws {
        var j = Journal(); let id = j.activities[0].id, original = j
        XCTAssertThrowsError(try GoalReports.saveWeeklyGoal(&j, activityID: id, minutes: 0, at: base))
        XCTAssertThrowsError(try GoalReports.saveWeeklyGoal(&j, activityID: id, minutes: 10081, at: base))
        XCTAssertThrowsError(try GoalReports.saveWeeklyGoal(&j, activityID: UUID(), minutes: 60, at: base))
        XCTAssertEqual(j, original)
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: base)
        try GoalReports.saveWeeklyGoal(&j, activityID: id, minutes: 10080, at: base)
        try Engine.record(&j, entry: Entry(start: base, end: at(5), activityID: id))
        let goal = GoalReports.weeklyGoals(j, at: base)[0], entries = j.entries
        let removed = GoalReports.deleteGoal(&j, id: goal.id)
        XCTAssertEqual(GoalReports.weeklyGoals(j, at: base).count, 0)
        XCTAssertEqual(GoalReports.dailyGoals(j, at: base).count, 1)
        XCTAssertEqual(j.entries, entries)
        try GoalReports.restoreGoals(&j, goals: removed)
        XCTAssertEqual(GoalReports.weeklyGoals(j, at: base)[0].id, goal.id)
        XCTAssertEqual(j.entries, entries); try Engine.validate(j)
    }
}

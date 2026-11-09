import Foundation
import NhipCore

final class GoalTests {
    let base = Date(timeIntervalSince1970: 1_735_689_600)
    func at(_ minute: Double) -> Date { base.addingTimeInterval(minute * 60) }
    func testLegacyWeeklyGoalDecodesWithoutPeriod() throws {
        var j = legacyJournal()
        j.goals = [Goal(activityID: j.activities[0].id, direction: "increase", minutes: 180, effectiveFrom: base)]
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(j)) as! [String: Any]
        var goals = object["goals"] as! [[String: Any]]
        goals[0].removeValue(forKey: "period"); object["goals"] = goals
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: object))
        try Engine.validate(decoded)
        XCTAssertNil(decoded.goals[0].period)
        XCTAssertFalse(decoded.goals[0].isDaily)
        XCTAssertEqual(GoalReports.weeklyGoals(decoded, at: base).count, 1)
        XCTAssertEqual(GoalReports.dailyGoals(decoded, at: base).count, 0)
    }
    func testDailySaveUpsertsWithoutReplacingWeeklyGoals() throws {
        var j = legacyJournal()
        let id = j.activities[0].id
        j.goals = [Goal(activityID: id, direction: "increase", minutes: 180, effectiveFrom: base)]
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: base)
        let first = j.goals.first { $0.isDaily }!
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 60, at: at(1440))
        XCTAssertEqual(j.goals.count, 2)
        XCTAssertEqual(j.goals.first { $0.isDaily }?.id, first.id)
        XCTAssertEqual(j.goals.first { $0.isDaily }?.minutes, 60)
        XCTAssertEqual(j.goals.first { !$0.isDaily }?.minutes, 180)
        try Engine.validate(j)
    }
    func testDailyCheckCompletesOnlyAtThresholdForChosenActivity() throws {
        var j = legacyJournal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: base)
        let goal = j.goals[0]
        try Engine.record(&j, entry: Entry(start: base, end: at(15), activityID: id))
        XCTAssertFalse(GoalReports.progress(goal, journal: j, at: base, now: at(60)).isComplete)
        try Engine.record(&j, entry: Entry(start: at(15), end: at(45), activityID: j.activities[1].id))
        XCTAssertFalse(GoalReports.progress(goal, journal: j, at: base, now: at(60)).isComplete)
        try Engine.record(&j, entry: Entry(start: at(45), end: at(60), activityID: id))
        let progress = GoalReports.progress(goal, journal: j, at: base, now: at(60))
        XCTAssertEqual(progress.seconds, 1800); XCTAssertEqual(progress.fraction, 1)
        XCTAssertTrue(progress.isComplete)
    }
    func testDailyCheckResetsNextDayWithoutDeletingActivity() throws {
        var j = legacyJournal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: base)
        try Engine.record(&j, entry: Entry(start: base, end: at(30), activityID: id))
        let goal = j.goals[0], nextDay = j.preferences.calendar.date(byAdding: .day, value: 1, to: base)!
        XCTAssertTrue(GoalReports.progress(goal, journal: j, at: base, now: at(30)).isComplete)
        let next = GoalReports.progress(goal, journal: j, at: nextDay, now: nextDay)
        XCTAssertEqual(next.seconds, 0); XCTAssertFalse(next.isComplete)
        XCTAssertEqual(GoalReports.dailyGoals(j, at: nextDay).map(\.id), [goal.id])
        XCTAssertEqual(Reports.summarize(j, range: Reports.allTimeRange(j)).total, 1800)
    }
    func testDailyProgressClipsMidnightInReportTimezone() throws {
        var j = legacyJournal(); let id = j.activities[0].id, c = j.preferences.calendar
        let midnight = c.startOfDay(for: base), yesterday = c.date(byAdding: .day, value: -1, to: midnight)!
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: yesterday)
        try Engine.record(&j, entry: Entry(start: midnight.addingTimeInterval(-900), end: midnight.addingTimeInterval(900), activityID: id))
        let before = GoalReports.progress(j.goals[0], journal: j, at: yesterday, now: base)
        let after = GoalReports.progress(j.goals[0], journal: j, at: midnight, now: base)
        XCTAssertEqual(before.seconds, 900); XCTAssertEqual(after.seconds, 900)
        XCTAssertFalse(before.isComplete); XCTAssertFalse(after.isComplete)
        j.goals[0].minutes = 15
        XCTAssertTrue(GoalReports.progress(j.goals[0], journal: j, at: midnight, now: base).isComplete)
    }
    func testEditingActivityAutomaticallyUnchecksGoal() throws {
        var j = legacyJournal(); let id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: base)
        try Engine.record(&j, entry: Entry(start: base, end: at(30), activityID: id))
        XCTAssertTrue(GoalReports.progress(j.goals[0], journal: j, at: base, now: at(30)).isComplete)
        j.entries[0].activityID = j.activities[1].id
        XCTAssertFalse(GoalReports.progress(j.goals[0], journal: j, at: base, now: at(30)).isComplete)
        j.entries.removeAll()
        XCTAssertFalse(GoalReports.progress(j.goals[0], journal: j, at: base, now: at(30)).isComplete)
    }
    func testDeleteAndUndoPreserveActivityAndOtherGoals() throws {
        var j = legacyJournal(); let id = j.activities[0].id
        let weekly = Goal(activityID: id, direction: "increase", minutes: 180, effectiveFrom: base)
        j.goals = [weekly]
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 60, at: base)
        try Engine.record(&j, entry: Entry(start: base, end: at(30), activityID: id))
        let entries = j.entries, dailyID = j.goals.first { $0.isDaily }!.id
        let removed = GoalReports.deleteGoal(&j, id: dailyID)
        XCTAssertEqual(j.goals, [weekly]); XCTAssertEqual(j.entries, entries)
        try GoalReports.restoreGoals(&j, goals: removed)
        try GoalReports.restoreGoals(&j, goals: removed)
        XCTAssertEqual(j.goals.count, 2); XCTAssertEqual(j.entries, entries)
    }
    func testDeleteWeeklyGoalDoesNotResurfaceOlderRule() throws {
        var j = legacyJournal(); let id = j.activities[0].id
        let older = Goal(activityID: id, direction: "increase", minutes: 60, effectiveFrom: at(-1440))
        let current = Goal(activityID: id, direction: "increase", minutes: 180, effectiveFrom: base)
        j.goals = [older, current]
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: base)
        let removed = GoalReports.deleteGoal(&j, id: current.id)
        XCTAssertEqual(removed.count, 2); XCTAssertEqual(GoalReports.weeklyGoals(j, at: base).count, 0)
        XCTAssertEqual(GoalReports.dailyGoals(j, at: base).count, 1)
        try GoalReports.restoreGoals(&j, goals: removed)
        XCTAssertEqual(GoalReports.weeklyGoals(j, at: base).first?.id, current.id)
    }
    func testInvalidDailyTargetsAreRejectedAtomically() throws {
        var j = legacyJournal(); let id = j.activities[0].id, original = j
        XCTAssertThrowsError(try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 0, at: base))
        XCTAssertThrowsError(try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 1441, at: base))
        XCTAssertThrowsError(try GoalReports.saveDailyGoal(&j, activityID: UUID(), minutes: 60, at: base))
        XCTAssertEqual(j, original)
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 1440, at: base)
        try Engine.validate(j)
        j.goals.append(Goal(activityID: id, direction: "increase", minutes: 30, effectiveFrom: base, period: "day"))
        XCTAssertThrowsError(try Engine.validate(j))
    }
    func testDailyAndWeeklyGoalsRoundTripSQLite() throws {
        var j = legacyJournal(); let id = j.activities[0].id
        j.goals = [Goal(activityID: id, direction: "increase", minutes: 180, effectiveFrom: base)]
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: base)
        try Engine.record(&j, entry: Entry(start: base, end: at(30), activityID: id))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try Repository(url: directory.appendingPathComponent("goals.sqlite"))
        try repository.save(j); let loaded = try repository.load()
        XCTAssertEqual(loaded, j)
        XCTAssertTrue(GoalReports.progress(GoalReports.dailyGoals(loaded, at: base)[0], journal: loaded, at: base, now: at(30)).isComplete)
        XCTAssertFalse(GoalReports.progress(GoalReports.weeklyGoals(loaded, at: base)[0], journal: loaded, at: base, now: at(30)).isComplete)
    }
}

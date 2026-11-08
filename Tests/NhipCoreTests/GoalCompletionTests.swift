import Foundation
import NhipCore

final class GoalCompletionTests {
    func at(_ value: String) -> Date { ISO8601DateFormatter().date(from: value + "+07:00")! }
    func journal() -> Journal { var j = Journal(); SleepPlan.setEnabled(false, journal: &j); return j }
    func entry(_ j: inout Journal, activity: Int = 0, date: String, minutes: Int) throws {
        let start = at(date)
        try Engine.record(&j, entry: Entry(start: start, end: start.addingTimeInterval(Double(minutes * 60)), activityID: j.activities[activity].id))
    }
    func testRecurringOccurrencesAndSeparateRates() throws {
        var j = journal()
        try GoalReports.saveDailyGoal(&j, activityID: j.activities[0].id, minutes: 60, at: at("2025-11-03T12:00:00"))
        try GoalReports.saveDailyGoal(&j, activityID: j.activities[1].id, minutes: 30, at: at("2025-11-04T12:00:00"))
        try GoalReports.saveWeeklyGoal(&j, activityID: j.activities[0].id, minutes: 120, at: at("2025-11-03T12:00:00"))
        try entry(&j, date: "2025-11-03T08:00:00", minutes: 60)
        try entry(&j, date: "2025-11-04T08:00:00", minutes: 30)
        try entry(&j, date: "2025-11-05T08:00:00", minutes: 60)
        try entry(&j, activity: 1, date: "2025-11-04T09:00:00", minutes: 30)
        let before = j, summary = GoalReports.completionSummary(j, now: at("2025-11-05T12:00:00"))
        XCTAssertEqual(summary.daily.completed, 3); XCTAssertEqual(summary.daily.total, 5)
        XCTAssertEqual(summary.daily.rate!, 0.6, accuracy: 0.00001)
        XCTAssertEqual(summary.weekly.completed, 1); XCTAssertEqual(summary.weekly.total, 1)
        XCTAssertEqual(summary.weekly.rate!, 1); XCTAssertEqual(j, before)
    }
    func testWeeklyVersionsAndArchivedActivities() throws {
        var j = journal(); let id = j.activities[0].id
        try GoalReports.saveWeeklyGoal(&j, activityID: id, minutes: 60, at: at("2025-11-03T12:00:00"))
        try GoalReports.saveWeeklyGoal(&j, activityID: id, minutes: 120, at: at("2025-11-10T12:00:00"))
        try entry(&j, date: "2025-11-03T08:00:00", minutes: 60)
        try entry(&j, date: "2025-11-10T08:00:00", minutes: 90)
        try entry(&j, date: "2025-11-17T08:00:00", minutes: 120)
        j.activities[0].archived = true
        let s = GoalReports.completionSummary(j, now: at("2025-11-17T12:00:00"))
        XCTAssertEqual(s.weekly.completed, 2); XCTAssertEqual(s.weekly.total, 3)
        XCTAssertEqual(s.weekly.rate!, 2.0 / 3, accuracy: 0.00001)
    }
    func testDSTAndSundayMondayBoundary() throws {
        var j = journal(); j.preferences.timezone = "America/New_York"
        let c = j.preferences.calendar
        let sunday = ISO8601DateFormatter().date(from: "2025-11-02T12:00:00-05:00")!
        let day = c.dateInterval(of: .day, for: sunday)!
        XCTAssertEqual(day.duration, 25 * 3600)
        try GoalReports.saveDailyGoal(&j, activityID: j.activities[0].id, minutes: 15, at: sunday)
        try GoalReports.saveWeeklyGoal(&j, activityID: j.activities[0].id, minutes: 15, at: sunday)
        try Engine.record(&j, entry: Entry(start: day.end.addingTimeInterval(-900), end: day.end.addingTimeInterval(900), activityID: j.activities[0].id))
        let s = GoalReports.completionSummary(j, now: day.end.addingTimeInterval(1800))
        XCTAssertEqual(s.daily.completed, 2); XCTAssertEqual(s.daily.total, 2)
        XCTAssertEqual(s.weekly.completed, 2); XCTAssertEqual(s.weekly.total, 2)
    }
    func testEmptyAndFutureGoalsHaveNoRate() throws {
        var j = journal(); let now = at("2025-11-03T12:00:00")
        try GoalReports.saveDailyGoal(&j, activityID: j.activities[0].id, minutes: 30, at: at("2025-11-10T12:00:00"))
        try GoalReports.saveWeeklyGoal(&j, activityID: j.activities[0].id, minutes: 30, at: at("2025-11-10T12:00:00"))
        let s = GoalReports.completionSummary(j, now: now)
        XCTAssertEqual(s.daily.total, 0); XCTAssertNil(s.daily.rate)
        XCTAssertEqual(s.weekly.total, 0); XCTAssertNil(s.weekly.rate)
        let fresh = GoalReports.completionSummary(Journal(), now: now)
        XCTAssertEqual(fresh.daily.total, 4); XCTAssertEqual(fresh.daily.completed, 0); XCTAssertEqual(fresh.daily.rate!, 0)
    }
    func testSleepGoalsUseSleepHistoryAndActualDeadlines() throws {
        var j = Journal()
        try entry(&j, date: "2020-01-01T08:00:00", minutes: 60)
        try SleepTracking.start(&j, kind: .night, at: at("2025-11-03T23:00:00"))
        try SleepTracking.wake(&j, at: at("2025-11-04T07:00:59"))
        try SleepTracking.start(&j, kind: .nap, at: at("2025-11-04T12:30:59"))
        try SleepTracking.wake(&j, at: at("2025-11-04T13:31:00"))
        SleepPlan.setComplete(true, reminder: .napWake, journal: &j, on: at("2025-11-04T14:00:00"))
        let s = GoalReports.completionSummary(j, now: at("2025-11-04T14:00:00"))
        XCTAssertEqual(s.daily.completed, 3); XCTAssertEqual(s.daily.total, 8)
        XCTAssertEqual(s.daily.rate!, 3.0 / 8, accuracy: 0.00001)
    }
    func testLegacySleepGoalsAndDisabledPlan() throws {
        var j = Journal()
        SleepPlan.setComplete(true, reminder: .napSleep, journal: &j, on: at("2025-12-31T14:00:00"))
        let s = GoalReports.completionSummary(j, now: at("2026-01-01T00:00:00"))
        XCTAssertEqual(s.daily.completed, 1); XCTAssertEqual(s.daily.total, 8)
        SleepPlan.setEnabled(false, journal: &j)
        let off = GoalReports.completionSummary(j, now: at("2026-01-01T00:00:00"))
        XCTAssertEqual(off.daily.total, 0); XCTAssertNil(off.daily.rate)
    }
    func testLimitsWaitForWeekEndAndObservationExcluded() throws {
        var j = journal(); let now = at("2025-11-10T12:00:00")
        j.goals.append(Goal(activityID: j.activities[0].id, direction: "limit", minutes: 90, effectiveFrom: at("2025-11-03T00:00:00")))
        j.goals.append(Goal(activityID: j.activities[1].id, direction: "observe", minutes: 0, effectiveFrom: at("2025-11-03T00:00:00")))
        try entry(&j, date: "2025-11-03T08:00:00", minutes: 60)
        let s = GoalReports.completionSummary(j, now: now)
        XCTAssertEqual(s.weekly.completed, 1); XCTAssertEqual(s.weekly.total, 2)
    }
    func testEditingAndDeletingRecalculatesWithoutSavedCounters() throws {
        var j = journal(); let now = at("2025-11-03T12:00:00"), id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 30, at: now)
        try entry(&j, date: "2025-11-03T08:00:00", minutes: 30)
        XCTAssertEqual(GoalReports.completionSummary(j, now: now).daily.completed, 1)
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 60, at: now)
        XCTAssertEqual(GoalReports.completionSummary(j, now: now).daily.completed, 0)
        let removed = GoalReports.deleteGoal(&j, id: j.goals[0].id)
        XCTAssertEqual(GoalReports.completionSummary(j, now: now).daily.total, 0)
        try GoalReports.restoreGoals(&j, goals: removed)
        XCTAssertEqual(GoalReports.completionSummary(j, now: now).daily.total, 1)
    }
    func testLargeJournalDoesNotRescanEveryEntryForEveryDay() throws {
        var j = journal(); let base = at("2024-01-01T00:00:00"), id = j.activities[0].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 60, at: base)
        try GoalReports.saveWeeklyGoal(&j, activityID: id, minutes: 60, at: base)
        for index in 0..<105_120 {
            let start = base.addingTimeInterval(Double(index * 300))
            j.entries.append(Entry(start: start, end: start.addingTimeInterval(300), activityID: id))
        }
        let began = Date()
        let s = GoalReports.completionSummary(j, now: base.addingTimeInterval(365 * 86400))
        let elapsed = Date().timeIntervalSince(began)
        XCTAssertEqual(s.daily.completed, 365); XCTAssertEqual(s.daily.total, 366)
        XCTAssertEqual(s.weekly.completed, 53); XCTAssertEqual(s.weekly.total, 53)
        XCTAssertTrue(elapsed < 3)
        print(String(format: "Goal completion: 105120 entries, %.3fs", elapsed))
    }
    func testSleepBaselinePersistsAndCountsDaysWithoutMarkers() throws {
        var j = Journal(); let original = j
        SleepPlan.prepareStatistics(journal: &j, on: at("2025-11-03T12:00:00"))
        XCTAssertEqual(j.sleepReminders?.statisticsStartDay, "2025-11-03")
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j))
        XCTAssertEqual(decoded, j)
        SleepPlan.prepareStatistics(journal: &j, on: at("2025-11-05T12:00:00"))
        let summary = GoalReports.completionSummary(j, now: at("2025-11-05T12:00:00"))
        XCTAssertEqual(summary.daily.completed, 0); XCTAssertEqual(summary.daily.total, 12)
        XCTAssertEqual(j.entries, original.entries); XCTAssertEqual(j.goals, original.goals)
        XCTAssertEqual(j.preferences, original.preferences)
    }
    func testInvalidSleepStatisticsBaselineRejected() throws {
        var j = Journal(); j.sleepReminders = SleepReminderState()
        j.sleepReminders?.statisticsStartDay = "2025-02-30"
        XCTAssertThrowsError(try Engine.validate(j))
    }
    func testResetClearsOldTasksAndStartsWithFourToday() throws {
        var j = Journal()
        SleepPlan.prepareStatistics(journal: &j, on: at("2025-11-01T12:00:00"))
        try GoalReports.saveDailyGoal(&j, activityID: j.activities[0].id, minutes: 30, at: at("2025-11-01T12:00:00"))
        try GoalReports.saveWeeklyGoal(&j, activityID: j.activities[0].id, minutes: 60, at: at("2025-11-01T12:00:00"))
        try entry(&j, date: "2025-11-01T08:00:00", minutes: 60)
        SleepPlan.setComplete(true, reminder: .napSleep, journal: &j, on: at("2025-11-01T12:00:00"))
        j.reset(at: at("2025-11-08T00:05:00"))
        let s = GoalReports.completionSummary(j, now: at("2025-11-08T00:05:00"))
        XCTAssertEqual(j.sleepReminders?.statisticsStartDay, "2025-11-08")
        XCTAssertEqual(s.daily.total, 4); XCTAssertEqual(s.daily.completed, 0)
        XCTAssertEqual(s.weekly.total, 0); XCTAssertTrue(j.entries.isEmpty); XCTAssertTrue(j.goals.isEmpty)
        XCTAssertNil(j.sleepHistory); try Engine.validate(j)
    }
    func testPostMidnightSleepCannotMoveResetBaselineBack() throws {
        var j = Journal(); j.reset(at: at("2025-11-08T00:05:00"))
        try SleepTracking.start(&j, kind: .night, at: at("2025-11-08T00:10:00"))
        XCTAssertEqual(j.sleepHistory?.active?.goalDay, "2025-11-07")
        SleepPlan.prepareStatistics(journal: &j, on: at("2025-11-08T00:10:00"))
        XCTAssertEqual(j.sleepReminders?.statisticsStartDay, "2025-11-08")
        let s = GoalReports.completionSummary(j, now: at("2025-11-08T00:10:00"))
        XCTAssertEqual(s.daily.total, 4); XCTAssertEqual(s.daily.completed, 0)
        XCTAssertTrue(j.sleepHistory?.active != nil)
    }
    func testResetBaselineSurvivesReopenAndWake() throws {
        var j = Journal(); j.reset(at: at("2025-11-08T00:05:00"))
        try SleepTracking.start(&j, kind: .night, at: at("2025-11-08T00:10:00"))
        j = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j))
        SleepPlan.prepareStatistics(journal: &j, on: at("2025-11-08T06:30:00"))
        try SleepTracking.wake(&j, at: at("2025-11-08T07:00:00"))
        let s = GoalReports.completionSummary(j, now: at("2025-11-08T07:00:00"))
        XCTAssertEqual(s.daily.total, 4); XCTAssertEqual(s.daily.completed, 1)
        XCTAssertEqual(j.entries.count, 1)
        let next = GoalReports.completionSummary(j, now: at("2025-11-09T00:00:00"))
        XCTAssertEqual(next.daily.total, 8); XCTAssertEqual(next.daily.completed, 1)
    }
    func testExplicitBaselineExcludesEarlierLegacySleepGoals() throws {
        var j = Journal()
        SleepPlan.setComplete(true, reminder: .napSleep, journal: &j, on: at("2025-11-07T12:00:00"))
        j.sleepReminders?.statisticsStartDay = "2025-11-08"
        SleepPlan.prepareStatistics(journal: &j, on: at("2025-11-08T12:00:00"))
        let s = GoalReports.completionSummary(j, now: at("2025-11-08T12:00:00"))
        XCTAssertEqual(s.daily.total, 4); XCTAssertEqual(s.daily.completed, 0)
        XCTAssertEqual(j.sleepReminders?.completions.count, 1)
    }
}

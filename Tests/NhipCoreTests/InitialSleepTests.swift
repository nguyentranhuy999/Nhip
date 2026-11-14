import Foundation
import NhipCore

final class InitialSleepTests {
    func at(_ value: String) -> Date { ISO8601DateFormatter().date(from: value + "+07:00")! }
    func completed(_ j: Journal, on date: Date) -> Set<SleepReminder> {
        Set(SleepReminder.allCases.filter { SleepPlan.isComplete($0, journal: j, on: date) })
    }
    var three: Set<SleepReminder> { [.morningWake, .napSleep, .napWake] }
    func testNewStoreInitializesPassedDeadlinesAndPersists() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try Repository(url: directory.appendingPathComponent("first-open.sqlite"))
        let now = at("2025-11-03T14:00:00"), j = try repository.load(at: now)
        XCTAssertEqual(completed(j, on: now), three)
        XCTAssertEqual(j.sleepReminders?.statisticsStartDay, "2025-11-03")
        let summary = GoalReports.completionSummary(j, now: now)
        XCTAssertEqual(summary.daily.total, 4); XCTAssertEqual(summary.daily.completed, 3)
        XCTAssertEqual(summary.daily.rate!, 0.75)
        XCTAssertTrue(j.entries.isEmpty); XCTAssertNil(j.sleepHistory)
        try repository.save(j)
        XCTAssertEqual(try repository.load(at: at("2025-11-04T23:00:00")), j)
        XCTAssertEqual(try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j)), j)
    }
    func testResetOnlyCountsTodayWithPassedTasksCompleted() throws {
        var j = legacyJournal()
        SleepPlan.setComplete(true, reminder: .nightSleep, journal: &j, on: at("2025-11-01T23:00:00"))
        try GoalReports.saveDailyPlan(&j, activityID: j.activities[0].id, minutes: 60, on: at("2025-11-01T12:00:00"))
        let now = at("2025-11-03T14:00:00")
        j.reset(at: now)
        XCTAssertEqual(completed(j, on: now), three)
        XCTAssertEqual(j.sleepReminders?.statisticsStartDay, "2025-11-03")
        XCTAssertTrue(j.sleepReminders!.completions.isEmpty)
        XCTAssertEqual(j.sleepReminders?.initialCompletions?.count, 3)
        XCTAssertTrue(j.goals.isEmpty); XCTAssertTrue(j.entries.isEmpty)
        let summary = GoalReports.completionSummary(j, now: now)
        XCTAssertEqual(summary.daily.total, 4); XCTAssertEqual(summary.daily.completed, 3)
        XCTAssertEqual(summary.weekly.total, 0)
        j.reset(at: at("2025-11-04T06:00:00"))
        XCTAssertTrue(completed(j, on: at("2025-11-04T06:00:00")).isEmpty)
        XCTAssertEqual(j.sleepReminders?.statisticsStartDay, "2025-11-04")
    }
    func testExactBoundariesAndNightBelongsToComingMidnight() throws {
        for (time, expected) in [
            ("00:00:00", Set<SleepReminder>()),
            ("06:59:59", []),
            ("07:00:00", [.morningWake]),
            ("12:29:59", [.morningWake]),
            ("12:30:00", [.morningWake, .napSleep]),
            ("13:30:00", three),
            ("23:59:59", three)
        ] {
            var j = Journal(); let now = at("2025-11-03T" + time)
            SleepPlan.initializeFirstDay(journal: &j, on: now)
            XCTAssertEqual(completed(j, on: now), expected)
            XCTAssertFalse(SleepPlan.isComplete(.nightSleep, journal: j, on: now))
            try Engine.validate(j)
        }
    }
    func testCustomSchedulesUseGoalDeadlines() throws {
        var j = Journal(), schedule = SleepSchedule()
        schedule.nightSleep = 22 * 60; schedule.morningWake = 8 * 60
        schedule.napSleep = 13 * 60; schedule.napWake = 14 * 60
        try SleepPlan.setSchedule(schedule, journal: &j)
        SleepPlan.initializeFirstDay(journal: &j, on: at("2025-11-03T13:30:00"))
        XCTAssertEqual(completed(j, on: at("2025-11-03T13:30:00")), [.morningWake, .napSleep])
        var late = Journal(); try SleepPlan.setSchedule(schedule, journal: &late)
        SleepPlan.initializeFirstDay(journal: &late, on: at("2025-11-03T22:00:00"))
        XCTAssertEqual(completed(late, on: at("2025-11-03T22:00:00")), Set(SleepReminder.allCases))
        var afterMidnight = Journal(); schedule.nightSleep = 60
        try SleepPlan.setSchedule(schedule, journal: &afterMidnight)
        SleepPlan.initializeFirstDay(journal: &afterMidnight, on: at("2025-11-03T02:00:00"))
        XCTAssertTrue(completed(afterMidnight, on: at("2025-11-03T02:00:00")).isEmpty)
    }
    func testAllowanceDoesNotRepeatOnReopenOrNextDay() throws {
        var j = Journal(); let first = at("2025-11-03T06:00:00")
        SleepPlan.initializeFirstDay(journal: &j, on: first)
        XCTAssertEqual(j.sleepReminders?.initialCompletions, [])
        let original = j
        SleepPlan.initializeFirstDay(journal: &j, on: at("2025-11-03T14:00:00"))
        SleepPlan.initializeFirstDay(journal: &j, on: at("2025-11-04T14:00:00"))
        SleepPlan.prepareStatistics(journal: &j, on: at("2025-11-04T14:00:00"))
        XCTAssertEqual(j, original)
        XCTAssertTrue(completed(j, on: at("2025-11-04T14:00:00")).isEmpty)
        XCTAssertEqual(GoalReports.completionSummary(j, now: at("2025-11-04T14:00:00")).daily.completed, 0)
        var existing = legacyJournal()
        SleepPlan.setComplete(true, reminder: .napSleep, journal: &existing, on: first)
        let prior = existing; SleepPlan.initializeFirstDay(journal: &existing, on: at("2025-11-03T14:00:00"))
        XCTAssertEqual(existing, prior)
    }
    func testRealLateSleepDoesNotRemoveInitialCompletionsOrInventRest() throws {
        var j = Journal(); let first = at("2025-11-03T14:00:00")
        SleepPlan.initializeFirstDay(journal: &j, on: first)
        XCTAssertTrue(j.entries.isEmpty)
        try SleepTracking.start(&j, kind: .nap, at: at("2025-11-03T14:10:00"))
        try SleepTracking.wake(&j, at: at("2025-11-03T14:40:00"))
        XCTAssertFalse(j.sleepHistory!.sessions[0].isOnTime(.napSleep))
        XCTAssertFalse(j.sleepHistory!.sessions[0].isOnTime(.napWake))
        XCTAssertEqual(completed(j, on: first), three)
        let summary = GoalReports.completionSummary(j, now: at("2025-11-03T15:00:00"))
        XCTAssertEqual(summary.daily.completed, 3); XCTAssertEqual(summary.daily.total, 4)
        XCTAssertEqual(Reports.summarize(j, range: Reports.allTimeRange(j)).total, 1800)
        XCTAssertTrue(completed(j, on: at("2025-11-04T15:00:00")).isEmpty)
    }
    func testTogglingAndScheduleChangesKeepInitialSnapshot() throws {
        var j = Journal(); let now = at("2025-11-03T08:00:00")
        SleepPlan.initializeFirstDay(journal: &j, on: now)
        let snapshot = j.sleepReminders?.initialCompletions
        SleepPlan.setEnabled(false, journal: &j); SleepPlan.setEnabled(true, journal: &j)
        var schedule = SleepSchedule(); schedule.napSleep = 6 * 60; schedule.napWake = 6 * 60 + 30
        try SleepPlan.setSchedule(schedule, journal: &j)
        SleepPlan.initializeFirstDay(journal: &j, on: now)
        XCTAssertEqual(j.sleepReminders?.initialCompletions, snapshot)
        XCTAssertEqual(completed(j, on: now), [.morningWake])
        var disabled = Journal(); SleepPlan.setEnabled(false, journal: &disabled)
        let old = disabled; SleepPlan.initializeFirstDay(journal: &disabled, on: now)
        XCTAssertEqual(disabled, old)
    }
    func testLegacyExistingStoreIsNeverAutoCompleted() throws {
        var old = legacyJournal(); old.sleepReminders = SleepReminderState()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try Repository(url: directory.appendingPathComponent("existing.sqlite"))
        try repository.save(old)
        let loaded = try repository.load(at: at("2025-11-03T14:00:00"))
        XCTAssertEqual(loaded, old); XCTAssertNil(loaded.sleepReminders?.initialCompletions)
        XCTAssertTrue(completed(loaded, on: at("2025-11-03T14:00:00")).isEmpty)
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
        let state = object["sleepReminders"] as! [String: Any]
        XCTAssertNil(state["initialCompletions"])
        XCTAssertEqual(try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: object)), old)
    }
    func testInvalidInitialMarkersRejectedAndHistoryProtected() throws {
        var j = Journal(); SleepPlan.initializeFirstDay(journal: &j, on: at("2025-11-03T14:00:00"))
        var duplicate = j; duplicate.sleepReminders!.initialCompletions!.append(duplicate.sleepReminders!.initialCompletions![0])
        XCTAssertThrowsError(try Engine.validate(duplicate))
        var wrongDay = j; wrongDay.sleepReminders!.initialCompletions![0].day = "2025-11-02"
        XCTAssertThrowsError(try Engine.validate(wrongDay))
        var missingBaseline = j; missingBaseline.sleepReminders!.statisticsStartDay = nil
        XCTAssertThrowsError(try Engine.validate(missingBaseline))
        var edited = j; edited.sleepReminders!.initialCompletions = []
        XCTAssertThrowsError(try HistoryProtection.validateChange(from: j, to: edited, now: at("2025-11-04T00:00:00")))
        try Engine.validate(j)
    }
    func testTimezoneDSTAndYearBoundaryFirstDay() throws {
        let f = ISO8601DateFormatter()
        for date in ["2025-11-02T14:00:00-05:00", "2025-12-31T14:00:00-05:00"] {
            var j = Journal(); j.preferences.timezone = "America/New_York"
            let now = f.date(from: date)!, calendar = j.preferences.calendar
            SleepPlan.initializeFirstDay(journal: &j, on: now)
            XCTAssertEqual(completed(j, on: now), three)
            let next = calendar.date(byAdding: .day, value: 1, to: now)!
            XCTAssertTrue(completed(j, on: next).isEmpty)
            let summary = GoalReports.completionSummary(j, now: next)
            XCTAssertEqual(summary.daily.total, 8); XCTAssertEqual(summary.daily.completed, 3)
        }
    }
}

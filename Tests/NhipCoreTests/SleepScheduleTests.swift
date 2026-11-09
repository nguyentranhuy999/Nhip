import Foundation
import UserNotifications
import NhipCore

final class SleepScheduleTests {
    private func at(_ text: String) -> Date { ISO8601DateFormatter().date(from: text + "+07:00")! }
    private var custom: SleepSchedule {
        var s = SleepSchedule(); s.nightSleep = 23 * 60 + 20; s.morningWake = 6 * 60 + 45
        s.napSleep = 12 * 60 + 10; s.napWake = 13 * 60 + 5; return s
    }
    func testLegacyStateAndSessionsUseOriginalDefaultTimes() throws {
        var j = legacyJournal()
        try SleepTracking.start(&j, kind: .nap, at: at("2025-11-07T12:25:00"))
        try SleepTracking.wake(&j, at: at("2025-11-07T13:25:00"))
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(j)) as! [String: Any]
        if var state = object["sleepReminders"] as? [String: Any] { state.removeValue(forKey: "schedule"); object["sleepReminders"] = state }
        var history = object["sleepHistory"] as! [String: Any]
        var sessions = history["sessions"] as! [[String: Any]]
        for index in sessions.indices { sessions[index].removeValue(forKey: "schedule") }
        history["sessions"] = sessions; object["sleepHistory"] = history
        var decoded = try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(SleepPlan.schedule(decoded), SleepSchedule())
        XCTAssertNil(decoded.sleepHistory?.sessions[0].schedule)
        try SleepPlan.setSchedule(custom, journal: &decoded)
        XCTAssertTrue(SleepPlan.isComplete(.napSleep, journal: decoded, on: at("2025-11-07T14:00:00")))
        XCTAssertTrue(SleepPlan.isComplete(.napWake, journal: decoded, on: at("2025-11-07T14:00:00")))
        XCTAssertEqual(SleepTracking.deadlineTimeLabel(for: .napSleep, journal: decoded, on: at("2025-11-07T14:00:00")), "12:30")
        try Engine.validate(decoded)
    }
    func testSchedulePersistsWithoutChangingHistoryAndSurvivesDisable() throws {
        var j = legacyJournal()
        try GoalReports.saveDailyGoal(&j, activityID: j.activities[0].id, minutes: 60, at: at("2025-11-07T10:00:00"))
        let original = j
        try SleepPlan.setSchedule(custom, journal: &j)
        XCTAssertEqual(j.activities, original.activities); XCTAssertEqual(j.entries, original.entries)
        XCTAssertEqual(j.goals, original.goals); XCTAssertEqual(j.runtime, original.runtime)
        XCTAssertEqual(j.preferences, original.preferences)
        SleepPlan.setEnabled(false, journal: &j); XCTAssertEqual(SleepPlan.schedule(j), custom)
        SleepPlan.setEnabled(true, journal: &j); XCTAssertEqual(SleepPlan.schedule(j), custom)
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j)); XCTAssertEqual(decoded, j)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repo = try Repository(url: folder.appendingPathComponent("journal.sqlite"))
        try repo.save(j); XCTAssertEqual(try repo.load(), j)
        try SleepPlan.setSchedule(SleepSchedule(), journal: &j)
        XCTAssertNil(j.sleepReminders?.schedule); XCTAssertEqual(SleepPlan.schedule(j), SleepSchedule())
        try SleepPlan.setSchedule(custom, journal: &j); j.reset(); XCTAssertEqual(SleepPlan.schedule(j), SleepSchedule())
    }
    func testInvalidTimesAndOrderingAreRejectedAtomically() throws {
        var j = legacyJournal(); var invalid: [SleepSchedule] = []
        var s = custom; s.napSleep = -1; invalid.append(s)
        s = custom; s.nightSleep = 1440; invalid.append(s)
        s = custom; s.napWake = s.napSleep; invalid.append(s)
        s = custom; s.napWake = s.napSleep - 1; invalid.append(s)
        s = SleepSchedule(); s.nightSleep = 8 * 60; invalid.append(s)
        s = custom; s.morningWake = s.napSleep; invalid.append(s)
        for schedule in invalid {
            let before = j
            XCTAssertThrowsError(try SleepPlan.setSchedule(schedule, journal: &j)); XCTAssertEqual(j, before)
            j.sleepReminders = SleepReminderState(); j.sleepReminders?.schedule = schedule
            XCTAssertThrowsError(try Engine.validate(j)); j = before
        }
        try SleepTracking.start(&j, kind: .nap, at: at("2025-11-07T12:00:00"))
        j.sleepHistory?.sessions[0].schedule = invalid[0]
        XCTAssertThrowsError(try Engine.validate(j))
    }
    func testCustomNativeTriggersAndNextReminderFollowAllFourTimes() throws {
        let c = legacyJournal().preferences.calendar, schedule = custom
        try schedule.validate()
        for reminder in SleepReminder.allCases {
            let trigger = UNCalendarNotificationTrigger(dateMatching: reminder.dateComponents(calendar: c, schedule: schedule), repeats: true)
            XCTAssertEqual(trigger.dateComponents.hour, schedule[reminder] / 60)
            XCTAssertEqual(trigger.dateComponents.minute, schedule[reminder] % 60)
            XCTAssertEqual(trigger.dateComponents.timeZone, c.timeZone)
            XCTAssertTrue(trigger.repeats); XCTAssertNil(trigger.dateComponents.day)
        }
        var cursor = at("2025-11-07T05:00:00")
        for reminder in [SleepReminder.morningWake, .napSleep, .napWake, .nightSleep, .morningWake] {
            let next = SleepPlan.nextReminder(after: cursor, calendar: c, schedule: schedule)!
            XCTAssertEqual(next.reminder, reminder)
            XCTAssertEqual(c.component(.hour, from: next.date), schedule[reminder] / 60)
            XCTAssertEqual(c.component(.minute, from: next.date), schedule[reminder] % 60)
            cursor = next.date
        }
        XCTAssertEqual(SleepPlan.dayKey(cursor, calendar: c), "2025-11-08")
    }
    func testBeforeMidnightBedtimeAndWakeUseCustomDeadlines() throws {
        for (bed, wake, complete) in [("23:20:59", "06:45:59", true), ("23:21:00", "06:46:00", false)] {
            var j = legacyJournal(); try SleepPlan.setSchedule(custom, journal: &j)
            try SleepTracking.start(&j, kind: .night, at: at("2025-11-07T" + bed))
            try SleepTracking.wake(&j, at: at("2025-11-08T" + wake))
            XCTAssertEqual(j.sleepHistory?.sessions[0].goalDay, "2025-11-07")
            XCTAssertEqual(j.sleepHistory?.sessions[0].wakeGoalDay, "2025-11-08")
            XCTAssertEqual(SleepPlan.isComplete(.nightSleep, journal: j, on: at("2025-11-07T12:00:00")), complete)
            XCTAssertEqual(SleepPlan.isComplete(.morningWake, journal: j, on: at("2025-11-08T12:00:00")), complete)
            XCTAssertEqual(SleepPlan.goalDate(for: .nightSleep, scheduledAt: at("2025-11-07T23:20:00"), journal: j), at("2025-11-07T23:20:00"))
        }
    }
    func testAfterMidnightBedtimeBelongsToPreviousEveningAcrossYearBoundary() throws {
        var j = legacyJournal(); var schedule = custom; schedule.nightSleep = 60; schedule.morningWake = 8 * 60
        try SleepPlan.setSchedule(schedule, journal: &j)
        try SleepTracking.start(&j, kind: .night, at: at("2025-01-01T00:50:00"))
        try SleepTracking.wake(&j, at: at("2025-01-01T07:50:00"))
        XCTAssertEqual(j.sleepHistory?.sessions[0].goalDay, "2024-12-31")
        XCTAssertTrue(SleepPlan.isComplete(.nightSleep, journal: j, on: at("2024-12-31T12:00:00")))
        XCTAssertTrue(SleepPlan.isComplete(.morningWake, journal: j, on: at("2025-01-01T12:00:00")))
        let goal = SleepPlan.goalDate(for: .nightSleep, scheduledAt: at("2025-01-01T01:00:00"), journal: j)
        XCTAssertEqual(SleepPlan.dayKey(goal, calendar: j.preferences.calendar), "2024-12-31")
        XCTAssertEqual(j.sleepHistory?.sessions[0].deadline(for: .nightSleep), at("2025-01-01T01:00:00"))
    }
    func testChangingScheduleKeepsActiveAndHistoricalGoalResults() throws {
        var j = legacyJournal(); var first = custom; first.napSleep = 12 * 60 + 15; first.napWake = 13 * 60 + 15
        try SleepPlan.setSchedule(first, journal: &j)
        try SleepTracking.start(&j, kind: .nap, at: at("2025-11-07T12:14:00"))
        var second = custom; second.napSleep = 12 * 60; second.napWake = 13 * 60
        try SleepPlan.setSchedule(second, journal: &j)
        XCTAssertEqual(SleepTracking.deadlineTimeLabel(for: .napWake, journal: j, on: at("2025-11-07T12:30:00")), "13:15")
        try SleepTracking.wake(&j, at: at("2025-11-07T13:14:00"))
        XCTAssertTrue(SleepPlan.isComplete(.napWake, journal: j, on: at("2025-11-07T14:00:00")))
        XCTAssertTrue(SleepPlan.isComplete(.napSleep, journal: j, on: at("2025-11-07T14:00:00")))
        let sessions = j.sleepHistory, entries = j.entries
        let before = GoalReports.completionSummary(j, now: at("2025-11-07T14:00:00"))
        try SleepPlan.setSchedule(SleepSchedule(), journal: &j)
        let after = GoalReports.completionSummary(j, now: at("2025-11-07T14:00:00"))
        XCTAssertEqual(before.daily.completed, after.daily.completed)
        XCTAssertEqual(before.daily.total, after.daily.total)
        XCTAssertEqual(j.sleepHistory, sessions); XCTAssertEqual(j.entries, entries)
        XCTAssertEqual(j.sleepHistory?.sessions[0].schedule, first)
    }
    func testNewSessionsUseChangedScheduleAndPersistTheirSnapshot() throws {
        var j = legacyJournal(); try SleepPlan.setSchedule(custom, journal: &j)
        try SleepTracking.start(&j, kind: .nap, at: at("2025-11-07T12:11:00"))
        try SleepTracking.wake(&j, at: at("2025-11-07T13:04:00"))
        XCTAssertFalse(SleepPlan.isComplete(.napSleep, journal: j, on: at("2025-11-07T14:00:00")))
        XCTAssertTrue(SleepPlan.isComplete(.napWake, journal: j, on: at("2025-11-07T14:00:00")))
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j))
        XCTAssertEqual(decoded, j); XCTAssertEqual(decoded.sleepHistory?.sessions[0].schedule, custom)
        XCTAssertEqual(SleepTracking.deadlineTimeLabel(for: .napSleep, journal: j, on: at("2025-11-08T14:00:00")), "12:10")
    }
    func testCustomTimesRespectDSTLocalClockAndActualRestDuration() throws {
        var j = legacyJournal(); j.preferences.timezone = "America/New_York"
        var schedule = custom; schedule.nightSleep = 23 * 60 + 15; schedule.morningWake = 7 * 60 + 45
        try SleepPlan.setSchedule(schedule, journal: &j)
        let start = ISO8601DateFormatter().date(from: "2026-03-08T04:10:00Z")!
        let end = ISO8601DateFormatter().date(from: "2026-03-08T11:44:00Z")!
        try SleepTracking.start(&j, kind: .night, at: start); try SleepTracking.wake(&j, at: end)
        XCTAssertTrue(j.sleepHistory!.sessions[0].isOnTime(.nightSleep))
        XCTAssertTrue(j.sleepHistory!.sessions[0].isOnTime(.morningWake))
        XCTAssertEqual(j.entries[0].seconds, end.timeIntervalSince(start))
        let previous = ISO8601DateFormatter().date(from: "2026-03-07T12:45:00Z")!
        let next = j.preferences.calendar.nextDate(after: previous, matching: SleepReminder.morningWake.dateComponents(calendar: j.preferences.calendar, schedule: schedule), matchingPolicy: .nextTime)!
        XCTAssertEqual(next.timeIntervalSince(previous), 23 * 3600)
    }
}

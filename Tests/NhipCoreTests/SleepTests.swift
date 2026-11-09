import Foundation
import UserNotifications
import NhipCore

final class SleepTests {
    let midnight = ISO8601DateFormatter().date(from: "2026-12-31T17:00:00Z")! // 01/01/2027 in Vietnam.
    func testFourFixedDailyTimesAndNativeTriggers() {
        let c = legacyJournal().preferences.calendar
        XCTAssertEqual(SleepReminder.allCases.map(\.timeLabel), ["00:00", "07:00", "12:30", "13:30"])
        XCTAssertEqual(Set(SleepReminder.allCases.map(\.id)).count, 4)
        for reminder in SleepReminder.allCases {
            let components = reminder.dateComponents(calendar: c)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            XCTAssertTrue(trigger.repeats)
            XCTAssertEqual(trigger.dateComponents.timeZone, c.timeZone)
            XCTAssertEqual(trigger.dateComponents.hour, reminder.hour)
            XCTAssertEqual(trigger.dateComponents.minute, reminder.minute)
            XCTAssertNil(trigger.dateComponents.day); XCTAssertNil(trigger.dateComponents.month)
            XCTAssertNil(trigger.dateComponents.year); XCTAssertNil(trigger.dateComponents.weekday)
            let next = c.nextDate(after: midnight.addingTimeInterval(-1), matching: components, matchingPolicy: .nextTime)!
            XCTAssertEqual(c.component(.hour, from: next), reminder.hour)
            XCTAssertEqual(c.component(.minute, from: next), reminder.minute)
            XCTAssertEqual(SleepPlan.dayKey(next, calendar: c), "2027-01-01")
        }
    }
    func testDailyResetAtLocalMidnightAndNoAutomaticCompletion() {
        var j = legacyJournal()
        let before = midnight.addingTimeInterval(-1)
        SleepPlan.setComplete(true, reminder: .nightSleep, journal: &j, on: before)
        XCTAssertTrue(SleepPlan.isComplete(.nightSleep, journal: j, on: before))
        XCTAssertFalse(SleepPlan.isComplete(.nightSleep, journal: j, on: midnight))
        XCTAssertEqual(SleepPlan.dayKey(before, calendar: j.preferences.calendar), "2026-12-31")
        XCTAssertEqual(SleepPlan.dayKey(midnight, calendar: j.preferences.calendar), "2027-01-01")
        for reminder in SleepReminder.allCases {
            XCTAssertFalse(SleepPlan.isComplete(reminder, journal: j, on: midnight.addingTimeInterval(23 * 3600)))
        }
    }
    func testConfirmationIsIdempotentAndCanBeUnchecked() throws {
        var j = legacyJournal()
        for _ in 0..<3 { SleepPlan.setComplete(true, reminder: .napSleep, journal: &j, on: midnight) }
        SleepPlan.setComplete(true, reminder: .napWake, journal: &j, on: midnight)
        XCTAssertEqual(j.sleepReminders?.completions.count, 2)
        SleepPlan.setComplete(false, reminder: .napSleep, journal: &j, on: midnight)
        XCTAssertFalse(SleepPlan.isComplete(.napSleep, journal: j, on: midnight))
        XCTAssertTrue(SleepPlan.isComplete(.napWake, journal: j, on: midnight))
        try Engine.validate(j)
    }
    func testDisableKeepsHistoryAndIgnoresOldActions() throws {
        var j = legacyJournal()
        XCTAssertTrue(SleepPlan.isEnabled(j))
        SleepPlan.setComplete(true, reminder: .morningWake, journal: &j, on: midnight)
        let history = j.sleepReminders?.completions
        SleepPlan.setEnabled(false, journal: &j)
        SleepPlan.setComplete(true, reminder: .napWake, journal: &j, on: midnight)
        XCTAssertFalse(SleepPlan.isEnabled(j)); XCTAssertEqual(j.sleepReminders?.completions, history)
        SleepPlan.setEnabled(true, journal: &j)
        XCTAssertTrue(SleepPlan.isComplete(.morningWake, journal: j, on: midnight))
        XCTAssertFalse(SleepPlan.isComplete(.napWake, journal: j, on: midnight))
        try Engine.validate(j)
    }
    func testLegacyDataAndRoundTripPreserveOtherGoalsAndEntries() throws {
        var j = legacyJournal()
        try GoalReports.saveDailyGoal(&j, activityID: j.activities[0].id, minutes: 60, at: midnight)
        try GoalReports.saveWeeklyGoal(&j, activityID: j.activities[1].id, minutes: 180, at: midnight)
        try Engine.record(&j, entry: Entry(start: midnight.addingTimeInterval(-365 * 86400), end: midnight.addingTimeInterval(-365 * 86400 + 300), activityID: j.activities[0].id))
        let original = j
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(j)) as! [String: Any]
        json.removeValue(forKey: "sleepReminders")
        let legacy = try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy, j); XCTAssertTrue(SleepPlan.isEnabled(legacy))
        SleepPlan.setComplete(true, reminder: .nightSleep, journal: &j, on: midnight)
        SleepPlan.setEnabled(false, journal: &j)
        XCTAssertEqual(j.goals, original.goals); XCTAssertEqual(j.entries, original.entries)
        XCTAssertEqual(j.runtime, original.runtime); XCTAssertEqual(j.preferences, original.preferences)
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j))
        XCTAssertEqual(decoded, j)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repo = try Repository(url: folder.appendingPathComponent("journal.sqlite"))
        try repo.save(j); XCTAssertEqual(try repo.load(), j)
    }
    func testInvalidDatesDuplicatesAndUnknownReminderRejected() throws {
        var j = legacyJournal(); j.sleepReminders = SleepReminderState()
        j.sleepReminders?.completions = [SleepCompletion(reminder: .napSleep, day: "2026-02-30")]
        XCTAssertThrowsError(try Engine.validate(j))
        let duplicate = SleepCompletion(reminder: .napSleep, day: "2026-11-07")
        j.sleepReminders?.completions = [duplicate, duplicate]
        XCTAssertThrowsError(try Engine.validate(j))
        let unknown = Data("{\"enabled\":true,\"completions\":[{\"reminder\":\"unknown\",\"day\":\"2026-11-07\"}]}".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(SleepReminderState.self, from: unknown))
    }
    func testDSTUsesLocalWallClock() {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/New_York")!
        let before = ISO8601DateFormatter().date(from: "2026-03-07T12:00:00Z")! // 07:00 before DST.
        let components = SleepReminder.morningWake.dateComponents(calendar: c)
        let next = c.nextDate(after: before, matching: components, matchingPolicy: .nextTime)!
        XCTAssertEqual(c.component(.hour, from: next), 7)
        XCTAssertEqual(next.timeIntervalSince(before), 23 * 3600)
    }
}

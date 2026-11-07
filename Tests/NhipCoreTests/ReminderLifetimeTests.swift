import Foundation
import NhipCore

final class ReminderLifetimeTests {
    let base = Date(timeIntervalSince1970: 1_799_000_000)
    func testSixSoundsThenExpireAtSixtySeconds() {
        var reminder = ReminderLifetime(at: base, uptime: 1000)
        var sounds: [Int] = [], expirations: [Int] = []
        for second in 0...80 {
            let result = reminder.step(at: base.addingTimeInterval(Double(second)), uptime: 1000 + Double(second))
            if result.sound { sounds.append(second) }
            if result.expired { expirations.append(second) }
        }
        XCTAssertEqual(sounds, [0, 10, 20, 30, 40, 50])
        XCTAssertEqual(expirations, [60]); XCTAssertFalse(reminder.isActive)
        XCTAssertNil(reminder.nextDelay(at: base.addingTimeInterval(80), uptime: 1080))
    }
    func testClosingOrAnsweringStopsAllFutureSounds() {
        var reminder = ReminderLifetime(at: base, uptime: 1000)
        XCTAssertTrue(reminder.step(at: base, uptime: 1000).sound)
        reminder.cancel()
        for second in [10, 20, 30, 60, 300] {
            let result = reminder.step(at: base.addingTimeInterval(Double(second)), uptime: 1000 + Double(second))
            XCTAssertFalse(result.sound); XCTAssertFalse(result.expired)
        }
    }
    func testDelayedTimerDoesNotBurstOrExtendDeadline() {
        var reminder = ReminderLifetime(at: base, uptime: 1000)
        _ = reminder.step(at: base, uptime: 1000)
        XCTAssertTrue(reminder.step(at: base.addingTimeInterval(35), uptime: 1035).sound)
        XCTAssertFalse(reminder.step(at: base.addingTimeInterval(35.1), uptime: 1035.1).sound)
        XCTAssertEqual(reminder.nextDelay(at: base.addingTimeInterval(35), uptime: 1035)!, 5, accuracy: 0.001)
        let afterWake = reminder.step(at: base.addingTimeInterval(3600), uptime: 1036)
        XCTAssertTrue(afterWake.expired); XCTAssertFalse(afterWake.sound)
    }
    func testBackwardClockCannotExtendVisibleReminder() {
        var reminder = ReminderLifetime(at: base, uptime: 1000)
        _ = reminder.step(at: base, uptime: 1000)
        let result = reminder.step(at: base.addingTimeInterval(-3600), uptime: 1060)
        XCTAssertTrue(result.expired); XCTAssertFalse(result.sound)
    }
    func testBoundaryAndRepeatedTimerCallbacks() {
        var reminder = ReminderLifetime(at: base, uptime: 1000)
        XCTAssertTrue(reminder.step(at: base, uptime: 1000).sound)
        XCTAssertFalse(reminder.step(at: base, uptime: 1000).sound)
        XCTAssertFalse(reminder.step(at: base.addingTimeInterval(9.999), uptime: 1009.999).sound)
        XCTAssertTrue(reminder.step(at: base.addingTimeInterval(10), uptime: 1010).sound)
        XCTAssertTrue(reminder.step(at: base.addingTimeInterval(59.999), uptime: 1059.999).sound)
        let expired = reminder.step(at: base.addingTimeInterval(60), uptime: 1060)
        XCTAssertTrue(expired.expired); XCTAssertFalse(expired.sound)
    }
    func testNewReminderHasIndependentDeadline() {
        var first = ReminderLifetime(at: base, uptime: 1000)
        first.cancel()
        var next = ReminderLifetime(at: base.addingTimeInterval(300), uptime: 1300)
        XCTAssertTrue(next.step(at: base.addingTimeInterval(300), uptime: 1300).sound)
        XCTAssertFalse(next.step(at: base.addingTimeInterval(359), uptime: 1359).expired)
        XCTAssertTrue(next.step(at: base.addingTimeInterval(360), uptime: 1360).expired)
    }
    func testSleepScheduleChoosesNearestSlotAndRollsIntoNextDay() {
        let c = Journal().preferences.calendar
        let beforeNap = ISO8601DateFormatter().date(from: "2026-11-07T05:29:59Z")!
        let nap = SleepPlan.nextReminder(after: beforeNap, calendar: c)!
        XCTAssertEqual(nap.reminder, .napSleep)
        XCTAssertEqual(nap.date.timeIntervalSince(beforeNap), 1)
        let wake = SleepPlan.nextReminder(after: nap.date, calendar: c)!
        XCTAssertEqual(wake.reminder, .napWake)
        XCTAssertEqual(wake.date.timeIntervalSince(nap.date), 3600)
        let night = SleepPlan.nextReminder(after: wake.date, calendar: c)!
        XCTAssertEqual(night.reminder, .nightSleep)
        XCTAssertEqual(SleepPlan.dayKey(night.date, calendar: c), "2026-11-08")
        XCTAssertEqual(c.component(.hour, from: night.date), 0)
    }
    func testSleepScheduleUsesReportTimezoneAtYearBoundary() {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/New_York")!
        let beforeMidnight = ISO8601DateFormatter().date(from: "2027-01-01T04:59:59Z")!
        let next = SleepPlan.nextReminder(after: beforeMidnight, calendar: c)!
        XCTAssertEqual(next.reminder, .nightSleep)
        XCTAssertEqual(next.date.timeIntervalSince(beforeMidnight), 1)
        XCTAssertEqual(SleepPlan.dayKey(next.date, calendar: c), "2027-01-01")
    }
}

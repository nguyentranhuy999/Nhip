import Foundation
import NhipCore

final class HistoryProtectionTests {
    func at(_ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        ISO8601DateFormatter().date(from: String(format: "2025-11-%02dT%02d:%02d:00+07:00", day, hour, minute))!
    }
    func journal() -> Journal { var j = legacyJournal(); SleepPlan.setEnabled(false, journal: &j); return j }
    func record(_ j: inout Journal, day: Int, hour: Int = 8) throws {
        try Engine.record(&j, entry: Entry(start: at(day, hour: hour), end: at(day, hour: hour + 1), activityID: j.activities[0].id))
    }
    func check(_ before: Journal, _ after: Journal, day: Int = 4, hour: Int = 12) throws {
        try Engine.validate(after)
        try HistoryProtection.validateChange(from: before, to: after, now: at(day, hour: hour))
    }
    func testPastDailyPlansCannotBeAddedChangedOrDeleted() throws {
        let empty = journal(); var j = empty
        try GoalReports.saveDailyPlan(&j, activityID: j.activities[0].id, minutes: 120, on: at(3))
        XCTAssertThrowsError(try check(empty, j))
        var edited = j
        try GoalReports.saveDailyPlan(&edited, activityID: j.activities[0].id, minutes: 180, on: at(3))
        XCTAssertThrowsError(try check(j, edited))
        var deleted = j
        _ = try GoalReports.deleteDailyPlan(&deleted, id: deleted.goals[0].id, on: at(3))
        XCTAssertThrowsError(try check(j, deleted))
    }
    func testTodayAndFutureDailyPlansRemainEditable() throws {
        var j = journal()
        try GoalReports.saveDailyPlan(&j, activityID: j.activities[0].id, minutes: 120, on: at(3))
        var updated = j
        try GoalReports.saveDailyPlan(&updated, activityID: j.activities[0].id, minutes: 180, on: at(4))
        try check(j, updated)
        j = updated
        try GoalReports.saveDailyPlan(&updated, activityID: j.activities[0].id, minutes: 240, on: at(5))
        try check(j, updated)
        j = updated
        _ = try GoalReports.deleteDailyPlan(&updated, id: GoalReports.dailyGoals(j, at: at(5))[0].id, on: at(5))
        try check(j, updated)
    }
    func testMidnightLocksStaleGoalEditorAndUndo() throws {
        var j = journal()
        try GoalReports.saveDailyPlan(&j, activityID: j.activities[0].id, minutes: 120, on: at(3))
        var deleted = j
        let change = try GoalReports.deleteDailyPlan(&deleted, id: j.goals[0].id, on: at(3))!
        try check(j, deleted, day: 3)
        var undone = deleted; try GoalReports.restoreDailyPlan(&undone, change: change)
        try check(deleted, undone, day: 3)
        XCTAssertThrowsError(try check(deleted, undone, day: 4, hour: 0))
        XCTAssertThrowsError(try check(j, deleted, day: 4, hour: 0))
    }
    func testEditingTodayCanSplitLegacyRangeWithoutChangingPast() throws {
        var j = journal()
        try GoalReports.saveDailyGoal(&j, activityID: j.activities[0].id, minutes: 120, at: at(1))
        var updated = j; GoalReports.prepareDailyPlans(&updated, at: at(4))
        try check(j, updated)
        j = updated
        try GoalReports.saveDailyPlan(&updated, activityID: j.activities[0].id, minutes: 180, on: at(4))
        try check(j, updated)
        XCTAssertEqual(GoalReports.dailyGoals(updated, at: at(3))[0].minutes, 120)
    }
    func testTodayEntriesCanBeAddedEditedAndDeleted() throws {
        let empty = journal(); var j = empty
        try record(&j, day: 4)
        try check(empty, j)
        var edited = j; edited.entries[0].end = at(4, hour: 10)
        try check(j, edited)
        var deleted = edited; deleted.entries = []
        try check(edited, deleted)
    }
    func testPastEntriesCannotBeAddedEditedDeletedOrReclassified() throws {
        let empty = journal(); var j = empty
        try record(&j, day: 3)
        XCTAssertThrowsError(try check(empty, j))
        var edited = j; edited.entries[0].end = at(3, hour: 10)
        XCTAssertThrowsError(try check(j, edited))
        edited = j; edited.entries[0].activityID = j.activities[1].id
        XCTAssertThrowsError(try check(j, edited))
        edited = j; edited.entries[0].note = "Changed"
        XCTAssertThrowsError(try check(j, edited))
        edited = j; edited.entries = []
        XCTAssertThrowsError(try check(j, edited))
    }
    func testBackdatingTodayEntryWithSameIDIsRejected() throws {
        var j = journal(); try record(&j, day: 4)
        var backdated = j; backdated.entries[0].start = at(3, hour: 23)
        XCTAssertThrowsError(try check(j, backdated))
    }
    func testReplacementCannotTrimAnOvernightHistoricalEntry() throws {
        var j = journal()
        try Engine.record(&j, entry: Entry(start: at(3, hour: 23), end: at(4, hour: 1), activityID: j.activities[0].id))
        var replaced = j
        try Engine.record(&replaced, entry: Entry(start: at(4, hour: 0), end: at(4, hour: 1), activityID: j.activities[1].id), replacing: true)
        XCTAssertThrowsError(try check(j, replaced))
        XCTAssertFalse(HistoryProtection.canEdit(j.entries[0], journal: j, now: at(4)))
    }
    func testOvernightSleepCanWakeButCannotThenBeDeleted() throws {
        var j = journal()
        try SleepTracking.start(&j, kind: .night, at: at(3, hour: 23))
        var waking = j; try SleepTracking.wake(&waking, at: at(4, hour: 7))
        try check(j, waking, hour: 7)
        let session = waking.sleepHistory!.sessions[0]
        var deleted = waking; try SleepTracking.delete(&deleted, sessionID: session.id, at: at(4))
        XCTAssertThrowsError(try check(waking, deleted))
        j = waking; waking.sleepHistory!.sessions[0].start = at(3, hour: 22)
        XCTAssertThrowsError(try check(j, waking))
    }
    func testOvernightManualActivityCanFinishOnlyWithOriginalStart() throws {
        var j = journal()
        let id = try PersonalTracking.start(&j, kind: .exercise, at: at(3, hour: 23))
        var finished = j; try PersonalTracking.finish(&finished, sessionID: id, at: at(4, hour: 7))
        try check(j, finished, hour: 7)
        var changedStart = j
        try PersonalTracking.finish(&changedStart, sessionID: id, at: at(4, hour: 7), start: at(3, hour: 22))
        XCTAssertThrowsError(try check(j, changedStart, hour: 7))
        var lateFinish = j
        try PersonalTracking.finish(&lateFinish, sessionID: id, at: at(3, hour: 23, minute: 30))
        XCTAssertThrowsError(try check(j, lateFinish))
        var deleted = finished; try PersonalTracking.delete(&deleted, sessionID: id, at: at(4))
        XCTAssertThrowsError(try check(finished, deleted))
    }
    func testPastActiveSessionsCannotBeCancelledOrBackdated() throws {
        var personal = journal()
        let id = try PersonalTracking.start(&personal, kind: .exercise, at: at(3, hour: 23))
        var deleted = personal; try PersonalTracking.delete(&deleted, sessionID: id, at: at(4))
        XCTAssertThrowsError(try check(personal, deleted))
        var sleep = journal(); try SleepTracking.start(&sleep, kind: .night, at: at(3, hour: 23))
        var cancelled = sleep; try SleepTracking.delete(&cancelled, sessionID: sleep.sleepHistory!.active!.id, at: at(4))
        XCTAssertThrowsError(try check(sleep, cancelled))
        let empty = journal(); var backdated = empty
        try SleepTracking.start(&backdated, kind: .nap, at: at(3))
        XCTAssertThrowsError(try check(empty, backdated))
    }
    func testOnlyLiveCrossMidnightCheckInCanRecordPreviousDayTime() throws {
        var j = journal()
        let span = Span(start: at(3, hour: 23, minute: 58), end: at(4, hour: 0, minute: 3))
        j.intervals = [span]
        var answer = j; try Engine.answer(&answer, intervalID: span.id, activityID: j.activities[0].id)
        try HistoryProtection.validateChange(from: j, to: answer, now: span.end.addingTimeInterval(30))
        XCTAssertThrowsError(try HistoryProtection.validateChange(from: j, to: answer, now: span.end.addingTimeInterval(60)))
        let older = Span(start: at(3, hour: 23, minute: 54), end: at(3, hour: 23, minute: 59))
        j.intervals = [older]; answer = j
        try Engine.answer(&answer, intervalID: older.id, activityID: j.activities[0].id)
        XCTAssertThrowsError(try check(j, answer, day: 4, hour: 0))
    }
    func testActivityAppearanceAndPreferencesDoNotChangeLockedHistory() throws {
        var j = journal(); try record(&j, day: 3)
        try GoalReports.saveDailyPlan(&j, activityID: j.activities[0].id, minutes: 120, on: at(3))
        var appearance = j
        appearance.activities[0].name = "New name"; appearance.activities[0].symbol = "star.fill"
        appearance.preferences.sound.toggle()
        try check(j, appearance)
    }
    func testLocalMidnightAndDSTDefineLockBoundary() throws {
        var j = journal(); j.preferences.timezone = "America/New_York"
        let f = ISO8601DateFormatter(), day = f.date(from: "2025-11-02T12:00:00-05:00")!
        let range = j.preferences.calendar.dateInterval(of: .day, for: day)!
        XCTAssertEqual(range.duration, 25 * 3600)
        XCTAssertFalse(HistoryProtection.isPast(range.start, journal: j, now: range.end.addingTimeInterval(-1)))
        XCTAssertTrue(HistoryProtection.isPast(range.start, journal: j, now: range.end))
        let empty = j
        try Engine.record(&j, entry: Entry(start: range.start, end: range.start.addingTimeInterval(1800), activityID: j.activities[0].id))
        try HistoryProtection.validateChange(from: empty, to: j, now: range.end.addingTimeInterval(-1))
        XCTAssertThrowsError(try HistoryProtection.validateChange(from: empty, to: j, now: range.end))
    }
    func testCompletedWeeksAreLockedButCurrentWeekCanChange() throws {
        var j = journal()
        try GoalReports.saveWeeklyGoal(&j, activityID: j.activities[0].id, minutes: 120, at: at(3))
        var edited = j
        try GoalReports.saveWeeklyGoal(&edited, activityID: j.activities[0].id, minutes: 180, at: at(3))
        try check(j, edited, day: 4)
        XCTAssertThrowsError(try check(j, edited, day: 10))
        edited = j
        try GoalReports.saveWeeklyGoal(&edited, activityID: j.activities[0].id, minutes: 180, at: at(10))
        try check(j, edited, day: 10)
    }
    func testReopenedHistoryStaysLockedWithoutChangingStatistics() throws {
        var j = journal(); try record(&j, day: 3)
        try GoalReports.saveDailyPlan(&j, activityID: j.activities[0].id, minutes: 60, on: at(3))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try Repository(url: directory.appendingPathComponent("locked.sqlite"))
        try repository.save(j); let loaded = try repository.load()
        XCTAssertEqual(loaded, j)
        XCTAssertFalse(HistoryProtection.canEdit(loaded.entries[0], journal: loaded, now: at(4)))
        XCTAssertEqual(GoalReports.completionSummary(loaded, now: at(4)).daily.completed, 1)
        var changed = loaded; changed.entries = []
        XCTAssertThrowsError(try check(loaded, changed))
        XCTAssertEqual(try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(loaded)), loaded)
    }
    func testLegacySleepCompletionMarkersAreProtected() throws {
        var j = legacyJournal()
        SleepPlan.setComplete(true, reminder: .napSleep, journal: &j, on: at(3))
        var changed = j; SleepPlan.setComplete(false, reminder: .napSleep, journal: &changed, on: at(3))
        XCTAssertThrowsError(try check(j, changed))
        changed = j; SleepPlan.setComplete(true, reminder: .napSleep, journal: &changed, on: at(4))
        try check(j, changed)
    }
}

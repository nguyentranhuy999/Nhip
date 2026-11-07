import Foundation
import NhipCore

final class SleepTrackingTests {
    func at(_ value: String) -> Date { ISO8601DateFormatter().date(from: value + "+07:00")! }
    var day: Date { at("2025-11-07T12:00:00") }
    var tomorrow: Date { at("2025-11-08T12:00:00") }

    func testNapCreatesExactRestEntryAndAutomaticGoals() throws {
        var j = Journal(); let start = at("2025-11-07T12:20:00"), end = at("2025-11-07T13:20:00")
        try SleepTracking.start(&j, kind: .nap, at: start)
        XCTAssertTrue(SleepPlan.isComplete(.napSleep, journal: j, on: day))
        XCTAssertFalse(SleepPlan.isComplete(.napWake, journal: j, on: day))
        XCTAssertTrue(j.entries.isEmpty)
        try SleepTracking.wake(&j, at: end)
        XCTAssertTrue(SleepPlan.isComplete(.napWake, journal: j, on: day))
        XCTAssertNil(j.sleepHistory?.active); XCTAssertEqual(j.entries.count, 1)
        let entry = j.entries[0]
        XCTAssertEqual(entry.start, start); XCTAssertEqual(entry.end, end); XCTAssertEqual(entry.seconds, 3600)
        XCTAssertEqual(entry.source, "sleep"); XCTAssertEqual(j.activity(entry.activityID)?.name, "Nghỉ ngơi")
        XCTAssertFalse(SleepPlan.isComplete(.napSleep, journal: j, on: tomorrow))
        try Engine.validate(j)
    }
    func testMinutePrecisionAtDeadlinesAndLateSleepStillRecordsRest() throws {
        var onTime = Journal()
        try SleepTracking.start(&onTime, kind: .nap, at: at("2025-11-07T12:30:59"))
        try SleepTracking.wake(&onTime, at: at("2025-11-07T13:30:59"))
        XCTAssertTrue(SleepPlan.isComplete(.napSleep, journal: onTime, on: day))
        XCTAssertTrue(SleepPlan.isComplete(.napWake, journal: onTime, on: day))
        var late = Journal()
        try SleepTracking.start(&late, kind: .nap, at: at("2025-11-07T12:31:00"))
        try SleepTracking.wake(&late, at: at("2025-11-07T13:31:00"))
        XCTAssertFalse(SleepPlan.isComplete(.napSleep, journal: late, on: day))
        XCTAssertFalse(SleepPlan.isComplete(.napWake, journal: late, on: day))
        XCTAssertEqual(late.entries[0].seconds, 3600)
    }
    func testNightGoalsBelongToEveningAndFollowingMorning() throws {
        var j = Journal()
        try SleepTracking.start(&j, kind: .night, at: at("2025-11-07T23:45:00"))
        try SleepTracking.wake(&j, at: at("2025-11-08T06:45:00"))
        XCTAssertTrue(SleepPlan.isComplete(.nightSleep, journal: j, on: day))
        XCTAssertFalse(SleepPlan.isComplete(.nightSleep, journal: j, on: tomorrow))
        XCTAssertTrue(SleepPlan.isComplete(.morningWake, journal: j, on: tomorrow))
        XCTAssertFalse(SleepPlan.isComplete(.morningWake, journal: j, on: day))
        let c = j.preferences.calendar, entry = j.entries[0]
        let first = Reports.summarize(j, range: c.dateInterval(of: .day, for: day)!)
        let second = Reports.summarize(j, range: c.dateInterval(of: .day, for: tomorrow)!)
        XCTAssertEqual(first.totals[entry.activityID] ?? 0, 900)
        XCTAssertEqual(second.totals[entry.activityID] ?? 0, 6.75 * 3600)
    }
    func testAfterMidnightBelongsToPreviousEveningAndCannotEarnLateGoal() throws {
        var j = Journal()
        try SleepTracking.start(&j, kind: .night, at: at("2025-11-08T00:01:00"))
        try SleepTracking.wake(&j, at: at("2025-11-08T07:01:00"))
        XCTAssertEqual(j.sleepHistory?.sessions[0].goalDay, "2025-11-07")
        XCTAssertFalse(SleepPlan.isComplete(.nightSleep, journal: j, on: day))
        XCTAssertFalse(SleepPlan.isComplete(.nightSleep, journal: j, on: tomorrow))
        XCTAssertFalse(SleepPlan.isComplete(.morningWake, journal: j, on: tomorrow))
        var exact = Journal()
        try SleepTracking.start(&exact, kind: .night, at: at("2025-11-08T00:00:59"))
        try SleepTracking.wake(&exact, at: at("2025-11-08T07:00:59"))
        XCTAssertTrue(SleepPlan.isComplete(.nightSleep, journal: exact, on: day))
        XCTAssertTrue(SleepPlan.isComplete(.morningWake, journal: exact, on: tomorrow))
    }
    func testEarlyWakeBeforeMidnightStillBelongsToPlannedMorning() throws {
        var j = Journal()
        try SleepTracking.start(&j, kind: .night, at: at("2025-11-07T22:00:00"))
        try SleepTracking.wake(&j, at: at("2025-11-07T23:50:00"))
        XCTAssertTrue(SleepPlan.isComplete(.morningWake, journal: j, on: tomorrow))
        XCTAssertFalse(SleepPlan.isComplete(.morningWake, journal: j, on: day))
    }
    func testTrackingStopsDuringSleepAndResumesWithNewFiveMinuteCycle() throws {
        var j = Journal()
        Engine.start(&j, at: at("2025-11-07T12:15:00"))
        try SleepTracking.start(&j, kind: .nap, at: at("2025-11-07T12:20:00"))
        let intervals = j.intervals
        XCTAssertNil(j.runtime.segmentStart); XCTAssertNil(j.runtime.nextDue)
        XCTAssertTrue(Engine.tick(&j, at: at("2025-11-07T13:00:00")).isEmpty)
        Engine.start(&j, at: at("2025-11-07T13:00:00"))
        Engine.recover(&j)
        XCTAssertEqual(j.intervals, intervals); XCTAssertNil(Engine.recentCheckIn(j, at: at("2025-11-07T12:21:00")))
        try SleepTracking.wake(&j, at: at("2025-11-07T13:20:00"))
        XCTAssertTrue(j.runtime.enabled)
        XCTAssertEqual(j.runtime.segmentStart, at("2025-11-07T13:20:00"))
        XCTAssertEqual(j.runtime.nextDue, at("2025-11-07T13:25:00"))
        XCTAssertEqual(j.intervals, intervals)
    }
    func testManualAndTimedPauseArePreservedAcrossSleep() throws {
        var paused = Journal()
        try SleepTracking.start(&paused, kind: .nap, at: at("2025-11-07T12:20:00"))
        try SleepTracking.wake(&paused, at: at("2025-11-07T13:20:00"))
        XCTAssertFalse(paused.runtime.enabled); XCTAssertNil(paused.runtime.nextDue)
        var timed = Journal()
        Engine.start(&timed, at: at("2025-11-07T12:15:00"))
        Engine.pause(&timed, at: at("2025-11-07T12:20:00"), minutes: 30)
        try SleepTracking.start(&timed, kind: .nap, at: at("2025-11-07T12:20:00"))
        try SleepTracking.wake(&timed, at: at("2025-11-07T13:20:00"))
        XCTAssertNil(timed.runtime.pauseUntil)
        XCTAssertEqual(timed.runtime.segmentStart, at("2025-11-07T13:20:00"))
        XCTAssertEqual(timed.intervals.count, 1)
    }
    func testRepeatedMarkersAndConflictsAreRejectedAtomically() throws {
        var j = Journal()
        try SleepTracking.start(&j, kind: .nap, at: at("2025-11-07T12:20:00"))
        var before = j
        XCTAssertThrowsError(try SleepTracking.start(&j, kind: .night, at: at("2025-11-07T12:21:00")))
        XCTAssertThrowsError(try SleepTracking.wake(&j, at: at("2025-11-07T12:20:00")))
        XCTAssertEqual(j, before)
        try Engine.record(&j, entry: Entry(start: at("2025-11-07T12:45:00"), end: at("2025-11-07T12:50:00"), activityID: j.activities[0].id))
        before = j
        XCTAssertThrowsError(try SleepTracking.wake(&j, at: at("2025-11-07T13:20:00")))
        XCTAssertEqual(j, before)
        var clean = Journal()
        try SleepTracking.start(&clean, kind: .nap, at: at("2025-11-07T12:20:00"))
        try SleepTracking.wake(&clean, at: at("2025-11-07T13:20:00"))
        before = clean
        XCTAssertThrowsError(try SleepTracking.wake(&clean, at: at("2025-11-07T13:21:00")))
        XCTAssertEqual(clean, before)
    }
    func testRestCategorySurvivesRenameAndArchive() throws {
        var j = Journal()
        try SleepTracking.start(&j, kind: .nap, at: at("2025-11-07T12:20:00"))
        try SleepTracking.wake(&j, at: at("2025-11-07T13:20:00"))
        let id = j.sleepHistory!.restActivityID!, index = j.activities.firstIndex { $0.id == id }!
        j.activities[index].name = "Nghỉ dưỡng"; j.activities[index].archived = true
        try SleepTracking.start(&j, kind: .night, at: at("2025-11-07T23:00:00"))
        try SleepTracking.wake(&j, at: at("2025-11-08T06:00:00"))
        XCTAssertTrue(j.entries.allSatisfy { $0.activityID == id })
        XCTAssertEqual(j.activities.count, 8)
        try Engine.validate(j)
    }
    func testDeleteSessionRemovesOnlyItsGeneratedRestAndUpdatesGoal() throws {
        var j = Journal()
        try SleepTracking.start(&j, kind: .nap, at: at("2025-11-07T12:20:00"))
        try SleepTracking.wake(&j, at: at("2025-11-07T13:20:00"))
        let session = j.sleepHistory!.sessions[0]
        try Engine.record(&j, entry: Entry(start: at("2025-11-07T14:00:00"), end: at("2025-11-07T15:00:00"), activityID: j.activities[0].id))
        let manual = j.entries[1]
        try SleepTracking.delete(&j, sessionID: session.id, at: at("2025-11-07T15:01:00"))
        XCTAssertEqual(j.entries, [manual]); XCTAssertFalse(SleepPlan.isComplete(.napSleep, journal: j, on: day))
        XCTAssertFalse(SleepPlan.isComplete(.napWake, journal: j, on: day))
        try SleepTracking.start(&j, kind: .night, at: at("2025-11-07T23:00:00"))
        let active = j.sleepHistory!.active!
        try SleepTracking.delete(&j, sessionID: active.id, at: at("2025-11-07T23:01:00"))
        XCTAssertNil(j.sleepHistory?.active); XCTAssertEqual(j.entries, [manual])
    }
    func testManualEditsArePreservedWhenDeletingSleepSession() throws {
        var j = Journal()
        try SleepTracking.start(&j, kind: .nap, at: at("2025-11-07T12:20:00"))
        try SleepTracking.wake(&j, at: at("2025-11-07T13:20:00"))
        j.entries[0].source = "edit"; let edited = j.entries[0]
        try SleepTracking.delete(&j, sessionID: j.sleepHistory!.sessions[0].id, at: at("2025-11-07T14:00:00"))
        XCTAssertEqual(j.entries, [edited])
    }
    func testActiveSleepAndFinishedHistoryRoundTripWithoutNetworkOrProcess() throws {
        var j = Journal()
        try SleepTracking.start(&j, kind: .night, at: at("2025-11-07T23:00:00"))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repo = try Repository(url: folder.appendingPathComponent("journal.sqlite"))
        try repo.save(j); var loaded = try repo.load(); Engine.recover(&loaded)
        XCTAssertEqual(loaded.sleepHistory, j.sleepHistory)
        try SleepTracking.wake(&loaded, at: at("2025-11-08T06:30:00"))
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(loaded))
        XCTAssertEqual(decoded, loaded); try repo.save(loaded); XCTAssertEqual(try repo.load(), loaded)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(j)) as! [String: Any]
        json.removeValue(forKey: "sleepHistory")
        XCTAssertNil(try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: json)).sleepHistory)
    }
    func testTimezoneChangesKeepOriginalDeadlinesAndDSTDuration() throws {
        var j = Journal(); j.preferences.timezone = "America/New_York"
        let start = ISO8601DateFormatter().date(from: "2025-03-09T04:00:00Z")! // 23:00 evening before DST.
        let end = ISO8601DateFormatter().date(from: "2025-03-09T11:00:00Z")! // 07:00 after DST.
        try SleepTracking.start(&j, kind: .night, at: start)
        j.preferences.timezone = "Asia/Ho_Chi_Minh"
        try SleepTracking.wake(&j, at: end)
        let session = j.sleepHistory!.sessions[0]
        XCTAssertTrue(session.isOnTime(.nightSleep)); XCTAssertTrue(session.isOnTime(.morningWake))
        XCTAssertEqual(j.entries[0].seconds, 7 * 3600)
        XCTAssertEqual(session.goalDay, "2025-03-08"); XCTAssertEqual(session.wakeGoalDay, "2025-03-09")
    }
    func testDisabledRemindersDoNotDisableManualSleepJournal() throws {
        var j = Journal(); SleepPlan.setEnabled(false, journal: &j)
        try SleepTracking.start(&j, kind: .nap, at: at("2025-11-07T12:20:00"))
        try SleepTracking.wake(&j, at: at("2025-11-07T13:20:00"))
        XCTAssertFalse(SleepPlan.isEnabled(j)); XCTAssertEqual(j.entries.count, 1)
        SleepPlan.setEnabled(true, journal: &j)
        XCTAssertTrue(SleepPlan.isComplete(.napSleep, journal: j, on: day))
    }
}

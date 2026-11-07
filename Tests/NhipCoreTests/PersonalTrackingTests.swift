import Foundation
import NhipCore

final class PersonalTrackingTests {
    let base = ISO8601DateFormatter().date(from: "2025-11-07T03:00:00Z")! // 10:00 Vietnam.
    func at(_ minutes: Double) -> Date { base.addingTimeInterval(minutes * 60) }
    func testQuickChoicesExcludePersonalCategoriesWithoutDeletingHistory() throws {
        var j = Journal()
        let sports = j.activities[2].id
        try Engine.record(&j, entry: Entry(start: base, end: at(30), activityID: sports))
        let original = j.entries
        let quick = PersonalTracking.quickActivities(j)
        XCTAssertEqual(quick.map(\.name), ["Học", "Nghiên cứu", "Giải trí", "Công việc", "Khác"])
        j.activities[2].name = "Chạy bộ"; j.activities[2].symbol = "heart.fill"
        j.activities[5].name = "Việc riêng"; j.activities[6].name = "Ngủ"
        XCTAssertEqual(PersonalTracking.quickActivities(j).map(\.id), quick.map(\.id))
        XCTAssertEqual(j.entries, original)
        XCTAssertEqual(Reports.summarize(j, range: DateInterval(start: base, end: at(30))).totals[sports], 1800)
    }
    func testLegacyCategoryMigrationIsIdempotentAndPreservesData() throws {
        var j = Journal()
        try GoalReports.saveDailyGoal(&j, activityID: j.activities[2].id, minutes: 60, at: base)
        let goals = j.goals
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(j)) as! [String: Any]
        var activities = json["activities"] as! [[String: Any]]
        for index in activities.indices { activities[index].removeValue(forKey: "personalKind") }
        json["activities"] = activities; json.removeValue(forKey: "personalHistory")
        var legacy = try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.personalHistory)
        XCTAssertEqual(PersonalTracking.quickActivities(legacy).count, 5)
        PersonalTracking.prepare(&legacy); let migrated = legacy; PersonalTracking.prepare(&legacy)
        XCTAssertEqual(legacy, migrated); XCTAssertEqual(legacy.goals, goals)
        XCTAssertEqual(legacy.activities.map(\.id), j.activities.map(\.id))
        XCTAssertEqual(legacy.activities[2].personalKind, .exercise)
        XCTAssertEqual(legacy.activities[5].personalKind, .personal)
        XCTAssertEqual(legacy.activities[6].personalKind, .rest)
    }
    func testExerciseCreatesOneEntryAndUpdatesDailyGoal() throws {
        var j = Journal(); let id = j.activities[2].id
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 60, at: base)
        let sessionID = try PersonalTracking.start(&j, kind: .exercise, at: base)
        XCTAssertTrue(j.isRecordingPersonalActivity); XCTAssertTrue(j.entries.isEmpty)
        XCTAssertEqual(try PersonalTracking.finish(&j, kind: .exercise, at: at(60)), sessionID)
        XCTAssertFalse(j.isRecordingPersonalActivity); XCTAssertEqual(j.entries.count, 1)
        let entry = j.entries[0]
        XCTAssertEqual(entry.activityID, id); XCTAssertEqual(entry.seconds, 3600); XCTAssertEqual(entry.source, "personal-timer")
        XCTAssertEqual(j.personalHistory?.sessions[0].entryID, entry.id)
        XCTAssertTrue(GoalReports.progress(j.goals[0], journal: j, at: base, now: at(60)).isComplete)
        try Engine.validate(j)
    }
    func testLateReturnCanEditBothTimesWithoutMovingTrackingClock() throws {
        var j = Journal(); Engine.start(&j, at: at(-5))
        let id = try PersonalTracking.start(&j, kind: .personal, at: base)
        try PersonalTracking.finish(&j, kind: .personal, at: at(240))
        let entryID = j.entries[0].id, runtime = j.runtime
        try PersonalTracking.edit(&j, sessionID: id, start: at(-15), end: at(90))
        XCTAssertEqual(j.entries.count, 1); XCTAssertEqual(j.entries[0].id, entryID)
        XCTAssertEqual(j.entries[0].seconds, 105 * 60)
        XCTAssertEqual(j.personalHistory?.sessions[0].start, at(-15)); XCTAssertEqual(j.personalHistory?.sessions[0].end, at(90))
        XCTAssertEqual(j.runtime, runtime)
        XCTAssertEqual(j.runtime.segmentStart, at(240)); XCTAssertEqual(j.runtime.nextDue, at(245))
    }
    func testFinishCanUseActualPastTimesAndResumeOnlyOnReturn() throws {
        var j = Journal(); Engine.start(&j, at: at(-5))
        try PersonalTracking.start(&j, kind: .exercise, at: base)
        try Engine.record(&j, entry: Entry(start: at(100), end: at(120), activityID: j.activities[0].id))
        try PersonalTracking.finish(&j, kind: .exercise, at: at(90), start: at(-10), resumeAt: at(240))
        XCTAssertEqual(j.entries[0].start, at(-10)); XCTAssertEqual(j.entries[0].end, at(90))
        XCTAssertEqual(j.entries[0].seconds, 100 * 60); XCTAssertEqual(j.entries.count, 2)
        XCTAssertEqual(j.runtime.segmentStart, at(240)); XCTAssertEqual(j.runtime.nextDue, at(245))
    }
    func testPersonalTimerStopsCheckInsAndRecoversAcrossClose() throws {
        var j = Journal(); Engine.start(&j, at: at(-5))
        try PersonalTracking.start(&j, kind: .exercise, at: base)
        let intervals = j.intervals
        XCTAssertNil(j.runtime.nextDue)
        XCTAssertTrue(Engine.tick(&j, at: at(120)).isEmpty)
        Engine.start(&j, at: at(130)); Engine.recover(&j)
        XCTAssertNil(j.runtime.nextDue); XCTAssertEqual(j.intervals, intervals)
        XCTAssertNil(Engine.recentCheckIn(j, at: at(1)))
        try PersonalTracking.finish(&j, kind: .exercise, at: at(180))
        XCTAssertEqual(j.runtime.segmentStart, at(180)); XCTAssertEqual(j.runtime.nextDue, at(185))
        XCTAssertEqual(j.intervals, intervals)
    }
    func testManualPauseRemainsPausedAndTimedPauseDoesNotBackfill() throws {
        var j = Journal()
        try PersonalTracking.start(&j, kind: .personal, at: base)
        try PersonalTracking.finish(&j, kind: .personal, at: at(90))
        XCTAssertFalse(j.runtime.enabled); XCTAssertNil(j.runtime.nextDue)
        var timed = Journal(); Engine.start(&timed, at: at(-5)); Engine.pause(&timed, at: base, minutes: 30)
        try PersonalTracking.start(&timed, kind: .personal, at: base)
        try PersonalTracking.finish(&timed, kind: .personal, at: at(60))
        XCTAssertNil(timed.runtime.pauseUntil); XCTAssertEqual(timed.runtime.segmentStart, at(60))
        XCTAssertEqual(timed.intervals.count, 1)
    }
    func testSleepAndPersonalSessionsCannotRunTogether() throws {
        var j = Journal()
        try PersonalTracking.start(&j, kind: .exercise, at: base); let active = j
        XCTAssertThrowsError(try PersonalTracking.start(&j, kind: .personal, at: at(1)))
        XCTAssertThrowsError(try SleepTracking.start(&j, kind: .nap, at: at(2)))
        XCTAssertThrowsError(try PersonalTracking.finish(&j, kind: .personal, at: at(3)))
        XCTAssertEqual(j, active)
        var sleeping = Journal(); try SleepTracking.start(&sleeping, kind: .nap, at: base); let before = sleeping
        XCTAssertThrowsError(try PersonalTracking.start(&sleeping, kind: .exercise, at: at(1)))
        XCTAssertEqual(sleeping, before)
    }
    func testEditAndFinishConflictsAreAtomic() throws {
        var j = Journal(); let id = try PersonalTracking.start(&j, kind: .exercise, at: base)
        try PersonalTracking.finish(&j, kind: .exercise, at: at(60))
        try Engine.record(&j, entry: Entry(start: at(120), end: at(150), activityID: j.activities[0].id))
        let original = j
        XCTAssertThrowsError(try PersonalTracking.edit(&j, sessionID: id, start: base, end: at(130)))
        XCTAssertThrowsError(try PersonalTracking.edit(&j, sessionID: id, start: at(70), end: at(60)))
        XCTAssertThrowsError(try PersonalTracking.edit(&j, sessionID: id, start: base, end: Date().addingTimeInterval(3600)))
        XCTAssertEqual(j, original)
        var conflict = Journal(); try PersonalTracking.start(&conflict, kind: .personal, at: base)
        try Engine.record(&conflict, entry: Entry(start: at(20), end: at(30), activityID: conflict.activities[0].id))
        let before = conflict
        XCTAssertThrowsError(try PersonalTracking.finish(&conflict, kind: .personal, at: at(60)))
        XCTAssertEqual(conflict, before)
    }
    func testDeleteOnlyOwnEntryAndCancelResumesRecording() throws {
        var j = Journal()
        let id = try PersonalTracking.start(&j, kind: .personal, at: base)
        try PersonalTracking.finish(&j, kind: .personal, at: at(60))
        try Engine.record(&j, entry: Entry(start: at(90), end: at(100), activityID: j.activities[0].id))
        let manual = j.entries[1]
        try PersonalTracking.delete(&j, sessionID: id, at: at(120))
        XCTAssertEqual(j.entries, [manual])
        Engine.start(&j, at: at(120))
        let active = try PersonalTracking.start(&j, kind: .exercise, at: at(125))
        try PersonalTracking.delete(&j, sessionID: active, at: at(130))
        XCTAssertFalse(j.isRecordingPersonalActivity); XCTAssertEqual(j.runtime.nextDue, at(135))
        XCTAssertEqual(j.entries, [manual])
    }
    func testRenamedArchivedCategoryStillUsesSameID() throws {
        var j = Journal(); let categoryID = j.activities[2].id
        j.activities[2].name = "Chạy bộ"; j.activities[2].symbol = "heart.fill"; j.activities[2].archived = true
        try PersonalTracking.start(&j, kind: .exercise, at: base)
        try PersonalTracking.finish(&j, kind: .exercise, at: at(60))
        XCTAssertEqual(j.entries[0].activityID, categoryID); XCTAssertEqual(j.activities.count, 8)
        XCTAssertFalse(PersonalTracking.quickActivities(j).contains { $0.id == categoryID })
    }
    func testActiveAndCompletedSessionsPersistWithLegacyCompatibility() throws {
        var j = Journal(); try PersonalTracking.start(&j, kind: .personal, at: base)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repo = try Repository(url: folder.appendingPathComponent("journal.sqlite"))
        try repo.save(j); var loaded = try repo.load(); Engine.recover(&loaded)
        XCTAssertEqual(loaded.personalHistory, j.personalHistory)
        try PersonalTracking.finish(&loaded, kind: .personal, at: at(60))
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(loaded))
        XCTAssertEqual(decoded, loaded); try repo.save(loaded); XCTAssertEqual(try repo.load(), loaded)
    }
    func testOvernightActivitySplitsReportsAtMidnight() throws {
        var j = Journal(); let c = j.preferences.calendar
        let midnight = c.date(byAdding: .day, value: 1, to: c.startOfDay(for: base))!
        try PersonalTracking.start(&j, kind: .exercise, at: midnight.addingTimeInterval(-1800))
        try PersonalTracking.finish(&j, kind: .exercise, at: midnight.addingTimeInterval(3600))
        let id = j.entries[0].activityID
        XCTAssertEqual(Reports.summarize(j, range: c.dateInterval(of: .day, for: base)!).totals[id], 1800)
        XCTAssertEqual(Reports.summarize(j, range: c.dateInterval(of: .day, for: midnight)!).totals[id], 3600)
    }
    func testInvalidSessionDataAndRestTimerAreRejected() throws {
        var j = Journal(); XCTAssertThrowsError(try PersonalTracking.start(&j, kind: .rest, at: base))
        try PersonalTracking.start(&j, kind: .exercise, at: base)
        var duplicate = j.personalHistory!.sessions[0]; duplicate.id = UUID()
        j.personalHistory?.sessions.append(duplicate)
        XCTAssertThrowsError(try Engine.validate(j))
        j.personalHistory?.sessions.removeLast()
        j.personalHistory?.sessions[0].activityID = UUID()
        XCTAssertThrowsError(try Engine.validate(j))
    }
}

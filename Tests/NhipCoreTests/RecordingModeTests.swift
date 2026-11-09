import Foundation
import NhipCore

final class RecordingModeTests {
    let base = Date(timeIntervalSince1970: 1_762_484_400)
    func at(_ minutes: Double) -> Date { base.addingTimeInterval(minutes * 60) }

    func testDefaultsAndLegacyMissingModeKeepExistingBehavior() throws {
        let j = legacyJournal()
        XCTAssertEqual(PersonalTracking.quickActivities(j).count, 5)
        XCTAssertEqual(PersonalTracking.manualActivities(j).map(\.id), [j.activities[2].id, j.activities[5].id])
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(j)) as! [String: Any]
        var activities = json["activities"] as! [[String: Any]]
        for index in activities.indices { activities[index].removeValue(forKey: "recordingMode") }
        json["activities"] = activities
        let old = try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(PersonalTracking.quickActivities(old).map(\.id), PersonalTracking.quickActivities(j).map(\.id))
        XCTAssertEqual(PersonalTracking.manualActivities(old).map(\.id), PersonalTracking.manualActivities(j).map(\.id))
    }
    func testBothAddsStudyAndResearchToBothLists() throws {
        var j = legacyJournal()
        for index in [0, 1] {
            let id = j.activities[index].id
            try PersonalTracking.setRecordingMode(&j, activityID: id, mode: .both, at: base)
            XCTAssertTrue(PersonalTracking.quickActivities(j).contains { $0.id == id })
            XCTAssertTrue(PersonalTracking.manualActivities(j).contains { $0.id == id })
        }
        XCTAssertEqual(PersonalTracking.quickActivities(j).count, 5)
        XCTAssertEqual(PersonalTracking.manualActivities(j).count, 4)
    }
    func testModesOverrideOldCategoryRulesAndSurviveRename() throws {
        var j = legacyJournal(); let study = j.activities[0].id, sports = j.activities[2].id
        try PersonalTracking.setRecordingMode(&j, activityID: study, mode: .manual, at: base)
        try PersonalTracking.setRecordingMode(&j, activityID: sports, mode: .reminder, at: base)
        j.activities[0].name = "Học ngoại tuyến"; j.activities[2].name = "Chạy bộ"
        PersonalTracking.prepare(&j)
        XCTAssertFalse(PersonalTracking.quickActivities(j).contains { $0.id == study })
        XCTAssertTrue(PersonalTracking.manualActivities(j).contains { $0.id == study })
        XCTAssertTrue(PersonalTracking.quickActivities(j).contains { $0.id == sports })
        XCTAssertFalse(PersonalTracking.manualActivities(j).contains { $0.id == sports })
        j.activities[2].archived = true
        XCTAssertFalse(PersonalTracking.quickActivities(j).contains { $0.id == sports })
    }
    func testBothOnlineAndOfflineAddOnceToSameGoal() throws {
        var j = legacyJournal(); let study = j.activities[0].id
        try PersonalTracking.setRecordingMode(&j, activityID: study, mode: .both, at: base)
        try GoalReports.saveDailyGoal(&j, activityID: study, minutes: 50, at: base)
        Engine.start(&j, at: base)
        let session = try PersonalTracking.start(&j, activityID: study, at: base)
        XCTAssertNil(j.personalHistory?.active?.kind)
        XCTAssertTrue(Engine.tick(&j, at: at(30)).isEmpty)
        try PersonalTracking.finish(&j, sessionID: session, at: at(45))
        let span = Engine.tick(&j, at: at(50))[0]
        try Engine.answer(&j, intervalID: span.id, activityID: study)
        try Engine.answer(&j, intervalID: span.id, activityID: study)
        XCTAssertEqual(j.entries.count, 2)
        XCTAssertEqual(j.entries.reduce(0) { $0 + $1.seconds }, 3000)
        XCTAssertTrue(j.entries.allSatisfy { $0.activityID == study })
        XCTAssertTrue(GoalReports.progress(j.goals[0], journal: j, at: base, now: at(50)).isComplete)
    }
    func testActiveSessionStaysFinishableAfterModeChangeAndArchive() throws {
        var j = legacyJournal(); let study = j.activities[0].id
        try PersonalTracking.setRecordingMode(&j, activityID: study, mode: .both, at: base)
        let session = try PersonalTracking.start(&j, activityID: study, at: base)
        try PersonalTracking.setRecordingMode(&j, activityID: study, mode: .reminder, at: at(10))
        j.activities[0].archived = true
        XCTAssertTrue(PersonalTracking.manualActivities(j).contains { $0.id == study })
        try PersonalTracking.finish(&j, sessionID: session, at: at(60))
        XCTAssertFalse(PersonalTracking.manualActivities(j).contains { $0.id == study })
        XCTAssertEqual(j.entries[0].activityID, study)
        XCTAssertEqual(j.entries[0].seconds, 3600)
    }
    func testAllManualStopsReminderClockAndReenableStartsFresh() throws {
        var j = legacyJournal(); Engine.start(&j, at: base)
        for id in PersonalTracking.quickActivities(j).map(\.id) {
            try PersonalTracking.setRecordingMode(&j, activityID: id, mode: .manual, at: at(1))
        }
        XCTAssertTrue(PersonalTracking.quickActivities(j).isEmpty)
        XCTAssertNil(j.runtime.nextDue)
        let count = j.intervals.count
        XCTAssertTrue(Engine.tick(&j, at: at(120)).isEmpty)
        XCTAssertEqual(j.intervals.count, count)
        XCTAssertNil(Engine.recentCheckIn(j, at: at(2)))
        try PersonalTracking.setRecordingMode(&j, activityID: j.activities[0].id, mode: .both, at: at(120))
        XCTAssertTrue(Engine.tick(&j, at: at(120)).isEmpty)
        XCTAssertEqual(j.runtime.nextDue, at(125))
    }
    func testRestStaysSpecialRegardlessOfMode() throws {
        var j = legacyJournal(); let rest = j.activities[6].id, before = j
        XCTAssertThrowsError(try PersonalTracking.setRecordingMode(&j, activityID: rest, mode: .both, at: base))
        XCTAssertEqual(j, before)
        j.activities[6].recordingMode = .both
        XCTAssertFalse(PersonalTracking.quickActivities(j).contains { $0.id == rest })
        XCTAssertFalse(PersonalTracking.manualActivities(j).contains { $0.id == rest })
        XCTAssertThrowsError(try PersonalTracking.start(&j, activityID: rest, at: base))
    }
    func testCustomActivityCanUseManualTimer() throws {
        var j = legacyJournal()
        let activity = Activity(name: "Đọc sách giấy", color: "6366F1", symbol: "book.closed.fill", recordingMode: .manual)
        j.activities.append(activity)
        let session = try PersonalTracking.start(&j, activityID: activity.id, at: base)
        try PersonalTracking.finish(&j, sessionID: session, at: at(60))
        XCTAssertEqual(j.entries[0].activityID, activity.id)
        XCTAssertFalse(PersonalTracking.quickActivities(j).contains { $0.id == activity.id })
        XCTAssertTrue(PersonalTracking.manualActivities(j).contains { $0.id == activity.id })
    }
    func testModesAndGenericSessionSurviveJSONAndSQLite() throws {
        var j = legacyJournal(); let study = j.activities[0].id
        try PersonalTracking.setRecordingMode(&j, activityID: study, mode: .both, at: base)
        let session = try PersonalTracking.start(&j, activityID: study, at: base)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repo = try Repository(url: folder.appendingPathComponent("journal.sqlite"))
        try repo.save(j); var loaded = try repo.load(); Engine.recover(&loaded)
        XCTAssertEqual(loaded.personalHistory, j.personalHistory)
        XCTAssertEqual(loaded.activities[0].recordingMode, .both)
        try PersonalTracking.finish(&loaded, sessionID: session, at: at(60))
        XCTAssertEqual(try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(loaded)), loaded)
        try repo.save(loaded); XCTAssertEqual(try repo.load(), loaded)
        var old = legacyJournal(); try PersonalTracking.start(&old, kind: .exercise, at: base)
        let oldLoaded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(old))
        XCTAssertEqual(oldLoaded.personalHistory?.active?.kind, .exercise)
    }
    func testSwitchingModePreservesHistoryGoalsAndPreferences() throws {
        var j = legacyJournal(); let study = j.activities[0].id
        try Engine.record(&j, entry: Entry(start: base, end: at(30), activityID: study))
        try GoalReports.saveDailyGoal(&j, activityID: study, minutes: 60, at: base)
        let before = j
        try PersonalTracking.setRecordingMode(&j, activityID: study, mode: .both, at: at(31))
        try PersonalTracking.setRecordingMode(&j, activityID: study, mode: .manual, at: at(32))
        XCTAssertEqual(j.entries, before.entries); XCTAssertEqual(j.goals, before.goals)
        XCTAssertEqual(j.preferences, before.preferences); XCTAssertEqual(j.sleepHistory, before.sleepHistory)
        XCTAssertEqual(j.activities.map(\.id), before.activities.map(\.id))
    }
    func testInvalidStartsAndWrongSessionAreAtomic() throws {
        var j = legacyJournal(); let before = j
        XCTAssertThrowsError(try PersonalTracking.start(&j, activityID: j.activities[0].id, at: base))
        XCTAssertEqual(j, before)
        try PersonalTracking.setRecordingMode(&j, activityID: j.activities[0].id, mode: .both, at: base)
        try PersonalTracking.start(&j, activityID: j.activities[0].id, at: base)
        let active = j
        XCTAssertThrowsError(try PersonalTracking.finish(&j, sessionID: UUID(), at: at(60)))
        XCTAssertEqual(j, active)
    }
    func testUnknownModeRejectedOnImport() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacyJournal().activities[0])) as! [String: Any]
        json["recordingMode"] = "unknown"
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try JSONDecoder().decode(Activity.self, from: data))
    }
}

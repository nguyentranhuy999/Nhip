import Foundation
import NhipCore

final class PriorityTests {
    func at(_ value: String) -> Date { ISO8601DateFormatter().date(from: value + "+07:00")! }
    func add(_ j: inout Journal, _ index: Int, _ start: String, minutes: Int, source: String = "manual") throws {
        let date = at(start)
        try Engine.record(&j, entry: Entry(start: date, end: date.addingTimeInterval(Double(minutes * 60)), activityID: j.activities[index].id, source: source))
    }
    func weekly(_ j: Journal) -> PriorityComparison {
        Reports.priorityComparison(j, period: .week, date: at("2025-11-10T12:00:00"), now: at("2025-11-17T12:00:00"))
    }
    func testUnselectedAndZeroPreviousDoNotInventPercentages() throws {
        var j = legacyJournal()
        try add(&j, 0, "2025-11-10T08:00:00", minutes: 60)
        let none = weekly(j)
        XCTAssertTrue(none.activityIDs.isEmpty); XCTAssertEqual(none.currentSeconds, 0); XCTAssertNil(none.changeFraction)
        j.activities[0].isPriority = true
        let selected = weekly(j)
        XCTAssertEqual(selected.currentSeconds, 3600); XCTAssertEqual(selected.previousSeconds, 0); XCTAssertNil(selected.changeFraction)
        let empty = weekly(legacyJournal())
        XCTAssertEqual(empty.currentSeconds, 0); XCTAssertEqual(empty.previousSeconds, 0)
    }
    func testMultiplePriorityActivitiesAndAllRecordingSources() throws {
        var j = legacyJournal()
        for index in [0, 1, 2] { j.activities[index].isPriority = true }
        try add(&j, 0, "2025-11-03T08:00:00", minutes: 60, source: "checkin")
        try add(&j, 1, "2025-11-03T09:00:00", minutes: 30)
        try add(&j, 0, "2025-11-10T08:00:00", minutes: 60, source: "checkin")
        try add(&j, 1, "2025-11-10T09:00:00", minutes: 30)
        try add(&j, 2, "2025-11-10T09:30:00", minutes: 45, source: "personal-timer")
        try add(&j, 6, "2025-11-10T12:00:00", minutes: 60, source: "sleep")
        try add(&j, 3, "2025-11-10T13:00:00", minutes: 120)
        let original = j, s = weekly(j)
        XCTAssertEqual(s.currentSeconds, 135 * 60); XCTAssertEqual(s.previousSeconds, 90 * 60)
        XCTAssertEqual(s.deltaSeconds, 45 * 60); XCTAssertEqual(s.changeFraction!, 0.5, accuracy: 0.00001)
        XCTAssertEqual(j, original)
        j.activities[6].isPriority = true
        XCTAssertEqual(weekly(j).currentSeconds, 195 * 60)
    }
    func testCurrentWeekUsesSameElapsedPartAndClipsEntries() throws {
        var j = legacyJournal(); j.activities[0].isPriority = true
        try add(&j, 0, "2025-11-03T08:00:00", minutes: 60)
        try add(&j, 0, "2025-11-05T10:00:00", minutes: 60)
        try add(&j, 0, "2025-11-09T08:00:00", minutes: 300)
        try add(&j, 0, "2025-11-10T08:00:00", minutes: 120)
        try add(&j, 0, "2025-11-12T09:30:00", minutes: 60)
        let now = at("2025-11-12T10:00:00")
        let s = Reports.priorityComparison(j, period: .week, date: now, now: now)
        XCTAssertEqual(s.currentRange.end, now); XCTAssertEqual(s.previousRange.end, at("2025-11-05T10:00:00"))
        XCTAssertEqual(s.currentSeconds, 150 * 60); XCTAssertEqual(s.previousSeconds, 60 * 60)
    }
    func testMonthBoundaryAndDifferentMonthLengths() throws {
        var j = legacyJournal(); j.activities[0].isPriority = true
        try add(&j, 0, "2025-03-31T23:30:00", minutes: 60)
        try add(&j, 0, "2025-04-30T23:30:00", minutes: 60)
        let s = Reports.priorityComparison(j, period: .month, date: at("2025-04-15T12:00:00"), now: at("2025-05-10T12:00:00"))
        XCTAssertEqual(s.currentSeconds, 3600); XCTAssertEqual(s.previousSeconds, 1800)
        XCTAssertEqual(s.currentRange.start, at("2025-04-01T00:00:00"))
        XCTAssertEqual(s.previousRange.start, at("2025-03-01T00:00:00"))
        XCTAssertEqual(s.changeFraction!, 1)
    }
    func testPrioritySurvivesRenameAndArchiveByID() throws {
        var j = legacyJournal(); j.activities[0].isPriority = true
        try add(&j, 0, "2025-11-10T08:00:00", minutes: 60)
        let before = weekly(j)
        j.activities[0].name = "Học ngoại tuyến"; j.activities[0].symbol = "pencil"; j.activities[0].archived = true
        let after = weekly(j)
        XCTAssertEqual(after.activityIDs, before.activityIDs); XCTAssertEqual(after.currentSeconds, before.currentSeconds)
        try Engine.validate(j)
    }
    func testLegacyAndJSONSQLitePersistence() throws {
        var j = legacyJournal(); j.activities[0].isPriority = true; j.activities[1].isPriority = false
        j.activities[0].recordingMode = .both
        let data = try JSONEncoder().encode(j)
        XCTAssertEqual(try JSONDecoder().decode(Journal.self, from: data), j)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = try Repository(url: folder.appendingPathComponent("journal.sqlite"))
        try repository.save(j); XCTAssertEqual(try repository.load(), j)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var activities = object["activities"] as! [[String: Any]]
        for index in activities.indices { activities[index].removeValue(forKey: "isPriority") }
        object["activities"] = activities
        let old = try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(weekly(old).activityIDs.isEmpty); XCTAssertEqual(old.activities[0].recordingMode, .both)
        activities[0]["isPriority"] = "yes"; object["activities"] = activities
        XCTAssertThrowsError(try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: object)))
    }
    func testPriorityChangesAndResetDoNotRewriteHistory() throws {
        var j = legacyJournal()
        try add(&j, 0, "2025-11-10T08:00:00", minutes: 60)
        try GoalReports.saveDailyGoal(&j, activityID: j.activities[0].id, minutes: 30, at: at("2025-11-10T12:00:00"))
        let entries = j.entries, goals = j.goals, preferences = j.preferences
        j.activities[0].isPriority = true; XCTAssertEqual(weekly(j).currentSeconds, 3600)
        j.activities[0].isPriority = false; XCTAssertEqual(weekly(j).currentSeconds, 0)
        XCTAssertEqual(j.entries, entries); XCTAssertEqual(j.goals, goals); XCTAssertEqual(j.preferences, preferences)
        j.activities[0].isPriority = true; j.reset(at: at("2025-11-11T12:00:00"))
        XCTAssertEqual(weekly(j).activityIDs.count, 5)
        XCTAssertEqual(weekly(j).currentSeconds, 0)
    }
    func testYearBoundaryAndNegativeChange() throws {
        var j = legacyJournal(); j.activities[0].isPriority = true
        try add(&j, 0, "2024-12-31T23:00:00", minutes: 120)
        try add(&j, 0, "2024-12-01T08:00:00", minutes: 60)
        let s = Reports.priorityComparison(j, period: .year, date: at("2025-06-01T12:00:00"), now: at("2026-01-10T12:00:00"))
        XCTAssertEqual(s.currentSeconds, 3600); XCTAssertEqual(s.previousSeconds, 7200)
        XCTAssertEqual(s.deltaSeconds, -3600); XCTAssertEqual(s.changeFraction!, -0.5)
    }
    func testDailyTotalsIncludeWholePreviousDay() throws {
        var j = legacyJournal(); j.activities[0].isPriority = true; j.activities[1].isPriority = true
        try add(&j, 0, "2025-11-07T20:00:00", minutes: 90)
        try add(&j, 0, "2025-11-08T08:00:00", minutes: 30, source: "checkin")
        try add(&j, 1, "2025-11-08T09:00:00", minutes: 30, source: "personal-timer")
        try add(&j, 6, "2025-11-08T10:00:00", minutes: 60, source: "sleep")
        let s = Reports.dailyPriorityTotals(j, date: at("2025-11-08T12:00:00"))
        XCTAssertEqual(s.currentSeconds, 3600); XCTAssertEqual(s.previousSeconds, 5400)
        XCTAssertEqual(s.currentRange.start, at("2025-11-08T00:00:00"))
        XCTAssertEqual(s.previousRange.end, s.currentRange.start)
        XCTAssertEqual(s.previousRange.start, at("2025-11-07T00:00:00"))
    }
    func testDailyTotalsClipMidnightAndRespectDST() throws {
        var j = legacyJournal(); j.preferences.timezone = "America/New_York"; j.activities[0].isPriority = true
        let c = j.preferences.calendar
        let sunday = ISO8601DateFormatter().date(from: "2025-11-02T12:00:00-05:00")!
        let day = c.dateInterval(of: .day, for: sunday)!
        try Engine.record(&j, entry: Entry(start: day.end.addingTimeInterval(-1800), end: day.end.addingTimeInterval(1800), activityID: j.activities[0].id))
        let s = Reports.dailyPriorityTotals(j, date: day.end.addingTimeInterval(3600))
        XCTAssertEqual(s.currentSeconds, 1800); XCTAssertEqual(s.previousSeconds, 1800)
        XCTAssertEqual(s.previousRange.duration, 25 * 3600); XCTAssertEqual(s.currentRange.duration, 24 * 3600)
        XCTAssertEqual(s.previousRange.start, day.start)
    }
    func testDailyTotalsFollowSelectedDateAndEmptySelection() throws {
        var j = legacyJournal(); j.activities[0].isPriority = true
        try add(&j, 0, "2025-11-30T08:00:00", minutes: 60)
        try add(&j, 0, "2025-12-01T08:00:00", minutes: 30)
        try add(&j, 0, "2025-12-02T08:00:00", minutes: 90)
        let first = Reports.dailyPriorityTotals(j, date: at("2025-12-01T12:00:00"))
        let second = Reports.dailyPriorityTotals(j, date: at("2025-12-02T12:00:00"))
        XCTAssertEqual(first.currentSeconds, 1800); XCTAssertEqual(first.previousSeconds, 3600)
        XCTAssertEqual(second.currentSeconds, 5400); XCTAssertEqual(second.previousSeconds, 1800)
        let entries = j.entries
        j.activities[0].isPriority = false
        let empty = Reports.dailyPriorityTotals(j, date: at("2025-12-02T12:00:00"))
        XCTAssertTrue(empty.activityIDs.isEmpty); XCTAssertEqual(empty.currentSeconds, 0); XCTAssertEqual(empty.previousSeconds, 0)
        XCTAssertEqual(j.entries, entries)
    }
}

import Foundation
import NhipCore

final class ActivityMetricTests {
    private func at(_ value: String) -> Date { ISO8601DateFormatter().date(from: value + "+07:00")! }
    func testRenamingAndAppearancePreserveTotalsAcrossEveryReportPeriod() throws {
        var j = legacyJournal(); let id = j.activities[0].id
        try Engine.record(&j, entry: Entry(start: at("2025-12-31T23:58:00"), end: at("2026-01-01T00:03:00"), activityID: id, source: "checkin"))
        try Engine.record(&j, entry: Entry(start: at("2026-01-01T01:00:00"), end: at("2026-01-01T01:10:00"), activityID: id, source: "manual"))
        try Engine.record(&j, entry: Entry(start: at("2026-01-01T01:10:00"), end: at("2026-01-01T01:20:00"), activityID: j.activities[1].id))
        try GoalReports.saveDailyGoal(&j, activityID: id, minutes: 60, at: at("2026-01-01T02:00:00"))
        let entries = j.entries, goals = j.goals
        var edited = j.activities[0]; edited.name = "Đọc và học"; edited.symbol = "pencil.circle.fill"; edited.color = "EF4444"
        try ActivityCatalog.update(&j, activity: edited)
        for period in ReportPeriod.allCases {
            let range = Reports.range(period, date: at("2026-01-01T02:00:00"), calendar: j.preferences.calendar)
            let cards = Reports.activityMetrics(j, range: range)
            let study = cards.first { $0.id == id }!
            XCTAssertEqual(study.seconds, period == .week ? 900 : 780)
            XCTAssertEqual(study.activity.name, "Đọc và học")
            XCTAssertEqual(study.activity.symbol, "pencil.circle.fill")
            XCTAssertEqual(study.activity.color, "EF4444")
            XCTAssertEqual(cards.reduce(0) { $0 + $1.seconds }, period == .week ? 1500 : 1380)
        }
        let all = Reports.activityMetrics(j, range: Reports.allTimeRange(j))
        XCTAssertEqual(all.first { $0.id == id }?.seconds, 900)
        XCTAssertEqual(j.entries, entries); XCTAssertEqual(j.goals, goals)
    }
    func testReusingOldNameDoesNotStealTotalsFromRenamedActivity() throws {
        var j = legacyJournal(); let original = j.activities[0].id
        var study = j.activities[0]; study.name = "Học tập"; study.symbol = "graduationcap.fill"
        try ActivityCatalog.update(&j, activity: study)
        let added = try ActivityCatalog.add(&j, name: "Học")
        try Engine.record(&j, entry: Entry(start: at("2025-11-07T09:00:00"), end: at("2025-11-07T09:10:00"), activityID: original))
        try Engine.record(&j, entry: Entry(start: at("2025-11-07T09:10:00"), end: at("2025-11-07T09:15:00"), activityID: added))
        let cards = Reports.activityMetrics(j, range: Reports.allTimeRange(j))
        XCTAssertEqual(cards.first { $0.id == original }?.seconds, 600)
        XCTAssertEqual(cards.first { $0.id == original }?.activity.name, "Học tập")
        XCTAssertEqual(cards.first { $0.id == original }?.activity.symbol, "graduationcap.fill")
        XCTAssertEqual(cards.first { $0.id == added }?.seconds, 300)
        XCTAssertEqual(cards.first { $0.id == added }?.activity.name, "Học")
        XCTAssertEqual(Set(cards.map(\.id)).count, j.activities.count)
    }
    func testCardsFollowSettingsOrderAndRetainArchivedHistory() throws {
        var j = legacyJournal(); let ids = j.activities.map(\.id)
        try Engine.record(&j, entry: Entry(start: at("2025-11-07T09:00:00"), end: at("2025-11-07T09:05:00"), activityID: ids[0]))
        j.activities[0].archived = true; j.activities[1].archived = true
        j.activities.swapAt(0, 2)
        let cards = Reports.activityMetrics(j, range: Reports.allTimeRange(j))
        XCTAssertEqual(cards.map(\.id), [ids[2], ids[0], ids[3], ids[4], ids[5], ids[6], ids[7]])
        XCTAssertEqual(cards.first { $0.id == ids[0] }?.seconds, 300)
        XCTAssertTrue(cards.first { $0.id == ids[0] }!.activity.archived)
        XCTAssertEqual(cards.first { $0.id == ids[7] }?.seconds, 0)
        let later = Reports.range(.day, date: at("2025-11-08T12:00:00"), calendar: j.preferences.calendar)
        XCTAssertFalse(Reports.activityMetrics(j, range: later).contains { $0.id == ids[0] })
    }
    func testCustomRestAndRenamedSleepRemainSeparateAfterReopening() throws {
        var j = legacyJournal(); let rest = j.activities[6].id
        var sleep = j.activities[6]; sleep.name = "Ngủ"; sleep.symbol = "bed.double.fill"
        try ActivityCatalog.update(&j, activity: sleep)
        let ordinary = try ActivityCatalog.add(&j, name: "Nghỉ ngơi")
        var custom = j.activity(ordinary)!; custom.symbol = "cup.and.saucer.fill"; custom.color = "EF4444"
        try ActivityCatalog.update(&j, activity: custom)
        try SleepTracking.start(&j, kind: .nap, at: at("2025-11-07T12:00:00"))
        try SleepTracking.wake(&j, at: at("2025-11-07T13:00:00"))
        try Engine.record(&j, entry: Entry(start: at("2025-11-07T14:00:00"), end: at("2025-11-07T14:10:00"), activityID: ordinary))
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repo = try Repository(url: folder.appendingPathComponent("journal.sqlite"))
        try repo.save(decoded); let reopened = try repo.load()
        let cards = Reports.activityMetrics(reopened, range: Reports.allTimeRange(reopened))
        XCTAssertEqual(cards.first { $0.id == rest }?.seconds, 3600)
        XCTAssertEqual(cards.first { $0.id == rest }?.activity.name, "Ngủ")
        XCTAssertEqual(cards.first { $0.id == rest }?.activity.symbol, "bed.double.fill")
        XCTAssertEqual(cards.first { $0.id == ordinary }?.seconds, 600)
        XCTAssertEqual(cards.first { $0.id == ordinary }?.activity.color, "EF4444")
        XCTAssertEqual(cards.first { $0.id == ordinary }?.activity.symbol, "cup.and.saucer.fill")
        XCTAssertEqual(reopened.entries, j.entries); XCTAssertEqual(reopened.sleepHistory, j.sleepHistory)
    }
}

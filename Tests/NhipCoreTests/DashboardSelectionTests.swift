import Foundation
import NhipCore

final class DashboardSelectionTests {
    private let base = Date(timeIntervalSince1970: 1_762_430_400)
    func testDefaultsChooseThreePrioritiesAndPrepareOnlyOnce() throws {
        var j = Journal()
        for index in [1, 4, 6, 7] { j.activities[index].isPriority = true }
        let expected = [j.activities[1].id, j.activities[4].id, j.activities[6].id]
        let original = j
        DashboardSelection.prepare(&j)
        for page in DashboardPage.allCases { XCTAssertEqual(DashboardSelection.selectedIDs(for: page, journal: j), expected) }
        XCTAssertEqual(j.entries, original.entries); XCTAssertEqual(j.goals, original.goals)
        XCTAssertEqual(j.activities, original.activities)
        j.activities.reverse()
        for index in j.activities.indices { j.activities[index].isPriority = false }
        DashboardSelection.prepare(&j)
        for page in DashboardPage.allCases { XCTAssertEqual(DashboardSelection.selectedIDs(for: page, journal: j), expected) }
        try Engine.validate(j)
    }
    func testDefaultsFillToThreeAndExcludeArchivedOnlyWhenInitializing() {
        var j = Journal(); j.activities[0].archived = true; j.activities[4].isPriority = true
        let ids = DashboardSelection.defaultIDs(j)
        XCTAssertEqual(ids, [j.activities[4].id, j.activities[1].id, j.activities[2].id])
        DashboardSelection.prepare(&j)
        j.activities[4].archived = true; DashboardSelection.prepare(&j)
        XCTAssertEqual(DashboardSelection.selectedIDs(for: .day, journal: j), ids)
        var single = Journal(); single.activities = [single.activities[0]]
        XCTAssertEqual(DashboardSelection.defaultIDs(single), [single.activities[0].id])
    }
    func testEachPageAllowsZeroToSixAndKeepsOtherPagesIndependent() throws {
        var j = Journal(); DashboardSelection.prepare(&j)
        let original = j.preferences.dashboardActivities
        let six = Array(j.activities.prefix(6).map(\.id)).reversed().map { $0 }
        try DashboardSelection.setSelected(six, for: .month, journal: &j)
        XCTAssertEqual(DashboardSelection.selectedIDs(for: .month, journal: j), six)
        for page in DashboardPage.allCases where page != .month {
            XCTAssertEqual(j.preferences.dashboardActivities?[page.rawValue], original?[page.rawValue])
        }
        try DashboardSelection.setSelected([], for: .day, journal: &j)
        DashboardSelection.prepare(&j)
        XCTAssertEqual(DashboardSelection.selectedIDs(for: .day, journal: j), [])
        XCTAssertEqual(DashboardSelection.selectedIDs(for: .month, journal: j), six)
        try Engine.validate(j)
    }
    func testSeventhDuplicateAndUnknownActivitiesAreRejectedAtomically() throws {
        var j = Journal(); DashboardSelection.prepare(&j)
        let id = j.activities[0].id
        for invalid in [Array(j.activities.prefix(7).map(\.id)), [id, id], [UUID()]] {
            let before = j
            XCTAssertThrowsError(try DashboardSelection.setSelected(invalid, for: .year, journal: &j))
            XCTAssertEqual(j, before)
            j.preferences.dashboardActivities?["year"] = invalid
            XCTAssertThrowsError(try Engine.validate(j)); j = before
        }
        j.preferences.dashboardActivities?["unknown-page"] = []
        XCTAssertThrowsError(try Engine.validate(j))
    }
    func testSelectedCardsFollowIDsOrderAndLiveMetadataAcrossAllPages() throws {
        var j = Journal(); let a = j.activities[0].id, b = j.activities[1].id
        try Engine.record(&j, entry: Entry(start: base, end: base.addingTimeInterval(600), activityID: a))
        try Engine.record(&j, entry: Entry(start: base.addingTimeInterval(600), end: base.addingTimeInterval(900), activityID: b))
        DashboardSelection.prepare(&j)
        for page in DashboardPage.allCases { try DashboardSelection.setSelected([b, a], for: page, journal: &j) }
        var renamed = j.activities[0]; renamed.name = "Học tập"; renamed.symbol = "graduationcap.fill"; renamed.color = "EF4444"
        try ActivityCatalog.update(&j, activity: renamed)
        let extra = try ActivityCatalog.add(&j, name: "Học")
        DashboardSelection.prepare(&j)
        for page in DashboardPage.allCases {
            let cards = Reports.dashboardMetrics(j, range: Reports.allTimeRange(j), page: page)
            XCTAssertEqual(cards.map(\.id), [b, a])
            XCTAssertEqual(cards[0].seconds, 300); XCTAssertEqual(cards[1].seconds, 600)
            XCTAssertEqual(cards[1].activity.name, "Học tập")
            XCTAssertEqual(cards[1].activity.symbol, "graduationcap.fill")
            XCTAssertEqual(cards[1].activity.color, "EF4444")
            XCTAssertFalse(cards.contains { $0.id == extra })
        }
        j.activities[0].archived = true
        XCTAssertTrue(Reports.dashboardMetrics(j, range: DateInterval(start: base.addingTimeInterval(86400), duration: 3600), page: .day)[1].activity.archived)
    }
    func testDashboardSelectionDoesNotAffectPriorityComparisonsOrFullReport() throws {
        var j = Journal(); j.activities[0].isPriority = true
        try Engine.record(&j, entry: Entry(start: base, end: base.addingTimeInterval(600), activityID: j.activities[0].id))
        try Engine.record(&j, entry: Entry(start: base.addingTimeInterval(600), end: base.addingTimeInterval(900), activityID: j.activities[1].id))
        let range = Reports.allTimeRange(j)
        let before = Reports.dailyPriorityTotals(j, date: base)
        try DashboardSelection.setSelected([j.activities[1].id], for: .summary, journal: &j)
        let after = Reports.dailyPriorityTotals(j, date: base)
        XCTAssertEqual(before.currentSeconds, after.currentSeconds)
        XCTAssertEqual(before.activityIDs, after.activityIDs)
        XCTAssertEqual(Reports.summarize(j, range: range).total, 900)
        XCTAssertEqual(Reports.dashboardMetrics(j, range: range, page: .summary).map(\.seconds), [300])
        XCTAssertTrue(j.activities[0].isPriority == true); XCTAssertTrue(j.activities[1].isPriority != true)
    }
    func testLegacyPersistenceEmptySelectionsAndReset() throws {
        var j = Journal()
        let legacy = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j))
        XCTAssertNil(legacy.preferences.dashboardActivities)
        XCTAssertEqual(DashboardSelection.selectedIDs(for: .day, journal: legacy).count, 3)
        DashboardSelection.prepare(&j)
        try DashboardSelection.setSelected([], for: .day, journal: &j)
        try DashboardSelection.setSelected(Array(j.activities.suffix(6).map(\.id)), for: .summary, journal: &j)
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j)); XCTAssertEqual(decoded, j)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repo = try Repository(url: folder.appendingPathComponent("journal.sqlite"))
        try repo.save(j); XCTAssertEqual(try repo.load(), j)
        XCTAssertEqual(Reports.dashboardMetrics(decoded, range: Reports.allTimeRange(decoded), page: .day).count, 0)
        j.reset(); DashboardSelection.prepare(&j)
        for page in DashboardPage.allCases { XCTAssertEqual(DashboardSelection.selectedIDs(for: page, journal: j).count, 3) }
    }
}

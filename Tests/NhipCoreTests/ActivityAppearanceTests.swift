import Foundation
import NhipCore

final class ActivityAppearanceTests {
    func testOrdinaryActivityStaysOrdinaryWhenChoosingPersonalIcons() throws {
        for symbol in ["figure.run", "house.fill", "cup.and.saucer.fill"] {
            var j = legacyJournal(); let original = j.activities[0]
            let date = Date(timeIntervalSince1970: 1_762_484_400)
            try GoalReports.saveDailyGoal(&j, activityID: original.id, minutes: 60, at: date)
            try Engine.record(&j, entry: Entry(start: date, end: date.addingTimeInterval(300), activityID: original.id))
            let entries = j.entries, goals = j.goals
            var changed = original; changed.symbol = symbol
            PersonalTracking.preserveRole(of: original, in: &changed)
            j.activities[0] = changed; PersonalTracking.prepare(&j)
            XCTAssertNil(PersonalTracking.kind(of: j.activities[0]))
            XCTAssertTrue(PersonalTracking.quickActivities(j).contains { $0.id == original.id })
            XCTAssertFalse(PersonalTracking.manualActivities(j).contains { $0.id == original.id })
            XCTAssertFalse(PersonalTracking.isRest(j.activities[0], journal: j))
            XCTAssertEqual(j.entries, entries); XCTAssertEqual(j.goals, goals)
            XCTAssertEqual(j.activities[0].recordingMode, original.recordingMode)
            XCTAssertEqual(j.activities[0].isPriority, original.isPriority)
            try Engine.validate(j)
        }
    }
    func testPersonalRolesSurviveChoosingUnrelatedIconsAndNames() throws {
        var j = legacyJournal()
        for index in [2, 5, 6] {
            let original = j.activities[index], role = PersonalTracking.kind(of: j.activities[index])
            var changed = original; changed.name = "Tên mới \(index)"; changed.symbol = "book.fill"
            PersonalTracking.preserveRole(of: original, in: &changed)
            j.activities[index] = changed
            XCTAssertEqual(PersonalTracking.kind(of: changed), role)
            XCTAssertEqual(PersonalTracking.recordingMode(of: changed), PersonalTracking.recordingMode(of: original))
        }
        PersonalTracking.prepare(&j)
        XCTAssertEqual(PersonalTracking.quickActivities(j).count, 5)
        XCTAssertTrue(PersonalTracking.isRest(j.activities[6], journal: j))
        try Engine.validate(j)
    }
    func testExplicitOrdinaryRolePersistsAndLegacyInferenceStillWorks() throws {
        var j = legacyJournal(); let original = j.activities[0]
        var changed = original; changed.symbol = "cup.and.saucer.fill"
        PersonalTracking.preserveRole(of: original, in: &changed); j.activities[0] = changed
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j))
        XCTAssertEqual(decoded, j); XCTAssertNil(PersonalTracking.kind(of: decoded.activities[0]))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = try Repository(url: folder.appendingPathComponent("journal.sqlite"))
        try repository.save(j); XCTAssertEqual(try repository.load(), j)
        let legacy = Activity(name: "Chạy", color: "6366F1", symbol: "figure.run")
        XCTAssertEqual(PersonalTracking.kind(of: legacy), .exercise)
        XCTAssertEqual(PersonalTracking.quickActivities(legacyJournal()).count, 5)
    }
}

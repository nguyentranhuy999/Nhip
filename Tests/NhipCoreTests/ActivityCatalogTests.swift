import Foundation
import NhipCore

final class ActivityCatalogTests {
    private let base = Date(timeIntervalSince1970: 1_762_430_400)
    func testDuplicateNamesAndWhitespaceAreRejectedAtomically() throws {
        var j = Journal()
        for name in ["Học", " HỌC ", "hoc", "Nghỉ ngơi", "NGHI  NGOI", "nghi\n\tngoi", "", " \t\n"] {
            let before = j
            XCTAssertThrowsError(try ActivityCatalog.add(&j, name: name))
            XCTAssertEqual(j, before)
        }
        _ = try ActivityCatalog.add(&j, name: "Đi bộ")
        let before = j
        XCTAssertThrowsError(try ActivityCatalog.add(&j, name: "di bo")); XCTAssertEqual(j, before)
        j.activities[0].archived = true
        let archived = j
        XCTAssertThrowsError(try ActivityCatalog.add(&j, name: "hoc")); XCTAssertEqual(j, archived)
    }
    func testRenamingRejectsConflictsButKeepsSelfAndHistory() throws {
        var j = Journal(); let study = j.activities[0]
        try Engine.record(&j, entry: Entry(start: base, end: base.addingTimeInterval(300), activityID: study.id))
        try GoalReports.saveDailyGoal(&j, activityID: study.id, minutes: 60, at: base)
        var edited = study; edited.name = " nghiên  cứu "
        let before = j
        XCTAssertThrowsError(try ActivityCatalog.update(&j, activity: edited)); XCTAssertEqual(j, before)
        edited.name = "  Học  "; edited.symbol = "cup.and.saucer.fill"
        try ActivityCatalog.update(&j, activity: edited)
        XCTAssertEqual(j.entries, before.entries); XCTAssertEqual(j.goals, before.goals)
        XCTAssertEqual(j.activities[0].id, study.id); XCTAssertNil(PersonalTracking.kind(of: j.activities[0]))
        edited.name = " "; let valid = j
        XCTAssertThrowsError(try ActivityCatalog.update(&j, activity: edited)); XCTAssertEqual(j, valid)
        edited.id = UUID(); edited.name = "Mới"
        XCTAssertThrowsError(try ActivityCatalog.update(&j, activity: edited)); XCTAssertEqual(j, valid)
    }
    func testNewActivitiesNeverInferRolesFromNamesOrIcons() throws {
        var j = Journal()
        j.activities[2].name = "Vận động"; j.activities[5].name = "Chăm sóc"; j.activities[6].name = "Ngủ"
        for (name, symbol) in [("Nghỉ ngơi", "cup.and.saucer.fill"), ("Tập thể thao", "figure.run"), ("Sinh hoạt cá nhân", "house.fill")] {
            let id = try ActivityCatalog.add(&j, name: name)
            var activity = j.activity(id)!; activity.symbol = symbol
            try ActivityCatalog.update(&j, activity: activity)
            PersonalTracking.prepare(&j)
            XCTAssertNil(PersonalTracking.kind(of: j.activity(id)!))
            XCTAssertFalse(PersonalTracking.isRest(j.activity(id)!, journal: j))
            try PersonalTracking.setRecordingMode(&j, activityID: id, mode: .both)
            XCTAssertTrue(PersonalTracking.quickActivities(j).contains { $0.id == id })
            XCTAssertTrue(PersonalTracking.manualActivities(j).contains { $0.id == id })
        }
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j))
        XCTAssertEqual(decoded, j)
        for activity in decoded.activities.suffix(3) { XCTAssertNil(PersonalTracking.kind(of: activity)) }
        try Engine.validate(j)
    }
    func testSleepUsesRenamedRestRoleInsteadOfOrdinaryNamesake() throws {
        var j = Journal(); let restID = j.activities[6].id
        j.activities[6].name = "Ngủ"
        let ordinary = try ActivityCatalog.add(&j, name: "Nghỉ ngơi")
        try SleepTracking.start(&j, kind: .nap, at: base)
        try SleepTracking.wake(&j, at: base.addingTimeInterval(3600))
        XCTAssertEqual(j.sleepHistory?.restActivityID, restID)
        XCTAssertTrue(j.entries.allSatisfy { $0.activityID == restID })
        XCTAssertNil(PersonalTracking.kind(of: j.activity(ordinary)!))
        XCTAssertEqual(j.activities.count, 9)
    }
    func testSleepCreatesUniqueSpecialCategoryIfOnlyOrdinaryNamesakeExists() throws {
        var j = Journal(); j.activities.remove(at: 6)
        let ordinary = try ActivityCatalog.add(&j, name: "Nghỉ ngơi")
        try SleepTracking.start(&j, kind: .nap, at: base)
        try SleepTracking.wake(&j, at: base.addingTimeInterval(3600))
        let special = j.sleepHistory!.restActivityID!
        XCTAssertTrue(special != ordinary)
        XCTAssertEqual(j.activity(special)?.name, "Nghỉ ngơi (2)")
        XCTAssertEqual(PersonalTracking.kind(of: j.activity(special)!), .rest)
        XCTAssertNil(PersonalTracking.kind(of: j.activity(ordinary)!))
        XCTAssertTrue(j.entries.allSatisfy { $0.activityID == special })
        try Engine.validate(j)
    }
    func testLegacyDuplicatesStillLoadWithoutDeletingOrMergingHistory() throws {
        var j = Journal(); let duplicate = Activity(name: "HỌC", color: "6366F1")
        j.activities.append(duplicate)
        try Engine.record(&j, entry: Entry(start: base, end: base.addingTimeInterval(300), activityID: duplicate.id))
        try Engine.validate(j)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = try Repository(url: folder.appendingPathComponent("journal.sqlite"))
        try repository.save(j); XCTAssertEqual(try repository.load(), j)
        let before = j
        XCTAssertThrowsError(try ActivityCatalog.add(&j, name: "hoc")); XCTAssertEqual(j, before)
        _ = try ActivityCatalog.add(&j, name: "Đọc sách giấy")
        XCTAssertEqual(j.entries, before.entries); XCTAssertEqual(j.activities.count, before.activities.count + 1)
    }
}

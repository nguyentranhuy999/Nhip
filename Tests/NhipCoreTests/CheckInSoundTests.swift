import Foundation
import NhipCore

final class CheckInSoundTests {
    func testLegacyJournalsEnableConfirmationWithoutChangingAlertSound() throws {
        let original = Journal()
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as! [String: Any]
        var preferences = object["preferences"] as! [String: Any]
        preferences.removeValue(forKey: "checkInSuccessSound"); object["preferences"] = preferences
        let journal = try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(journal.preferences.isCheckInSuccessSoundEnabled)
        XCTAssertFalse(journal.preferences.sound)
        XCTAssertEqual(journal, original)
        try Engine.validate(journal)
    }
    func testMutedConfirmationPersistsAndDoesNotChangeOtherPreferences() throws {
        var journal = Journal(); journal.preferences.sound = true
        InterfaceSection.summary.setSymbol("star.fill", in: &journal.preferences)
        let original = journal
        journal.preferences.checkInSuccessSound = false
        XCTAssertFalse(journal.preferences.isCheckInSuccessSoundEnabled)
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(journal))
        XCTAssertEqual(decoded, journal)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = try Repository(url: folder.appendingPathComponent("journal.sqlite"))
        try repository.save(journal); XCTAssertEqual(try repository.load(), journal)
        journal.preferences.checkInSuccessSound = nil
        XCTAssertEqual(journal, original)
        journal.preferences.checkInSuccessSound = false
        journal.reset(); XCTAssertTrue(journal.preferences.isCheckInSuccessSoundEnabled)
        try Engine.validate(journal)
    }
}

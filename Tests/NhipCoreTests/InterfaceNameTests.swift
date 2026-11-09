import Foundation
import NhipCore

final class InterfaceNameTests {
    func testLegacyDataKeepsDefaultNamesAndExistingIcons() throws {
        var original = Journal()
        InterfaceSection.day.setSymbol("star.fill", in: &original.preferences)
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as! [String: Any]
        var prefs = object["preferences"] as! [String: Any]
        prefs.removeValue(forKey: "interfaceTitles"); object["preferences"] = prefs
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded, original); XCTAssertNil(decoded.preferences.interfaceTitles)
        for section in InterfaceSection.allCases {
            XCTAssertEqual(section.title(in: decoded.preferences), section.title)
            XCTAssertNil(section.customTitle(in: decoded.preferences))
        }
        XCTAssertEqual(InterfaceSection.day.symbol(in: decoded.preferences), "star.fill")
        for period in ReportPeriod.allCases { XCTAssertEqual(InterfaceSection(period: period).rawValue, String(describing: period)) }
        try Engine.validate(decoded)
    }
    func testCustomNamesPersistWithoutChangingTrackingData() throws {
        var journal = Journal(); journal.preferences.checkInSuccessSound = false
        InterfaceSection.goals.setSymbol("flag.fill", in: &journal.preferences)
        let original = journal
        for section in InterfaceSection.allCases {
            section.setTitle("  🌱 Tên mới \n\t \(section.rawValue)  ", in: &journal.preferences)
            XCTAssertEqual(section.title(in: journal.preferences), "🌱 Tên mới \(section.rawValue)")
        }
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(journal))
        XCTAssertEqual(decoded, journal)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = try Repository(url: folder.appendingPathComponent("journal.sqlite"))
        try repository.save(journal); XCTAssertEqual(try repository.load(), journal)
        journal.preferences.interfaceTitles = nil
        XCTAssertEqual(journal, original)
        try Engine.validate(decoded)
    }
    func testBlankDefaultAndIndividualResetsPreserveOtherChoices() {
        var journal = Journal()
        InterfaceSection.day.setTitle("Hôm nay của tôi", in: &journal.preferences)
        InterfaceSection.goals.setTitle("Kế hoạch", in: &journal.preferences)
        InterfaceSection.goals.setSymbol("star.fill", in: &journal.preferences)
        InterfaceSection.day.setTitle("  \n\t", in: &journal.preferences)
        XCTAssertNil(InterfaceSection.day.customTitle(in: journal.preferences))
        XCTAssertEqual(InterfaceSection.goals.title(in: journal.preferences), "Kế hoạch")
        InterfaceSection.goals.setTitle(InterfaceSection.goals.title, in: &journal.preferences)
        XCTAssertNil(journal.preferences.interfaceTitles)
        XCTAssertEqual(InterfaceSection.goals.symbol(in: journal.preferences), "star.fill")
        InterfaceSection.summary.setTitle("Báo cáo", in: &journal.preferences)
        InterfaceSection.summary.setTitle(nil, in: &journal.preferences)
        XCTAssertNil(journal.preferences.interfaceTitles)
        InterfaceSection.personal.setTitle("Sinh hoạt", in: &journal.preferences)
        journal.reset(); XCTAssertNil(journal.preferences.interfaceTitles)
        XCTAssertEqual(InterfaceSection.personal.title(in: journal.preferences), "Hoạt động")
    }
}

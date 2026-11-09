import Foundation
import NhipCore

final class InterfaceIconTests {
    func testLegacyPreferencesUseDefaultIcons() throws {
        var j = Journal()
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(j)) as! [String: Any]
        var preferences = object["preferences"] as! [String: Any]
        preferences.removeValue(forKey: "interfaceIcons"); object["preferences"] = preferences
        j = try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(j.preferences.interfaceIcons)
        for section in InterfaceSection.allCases { XCTAssertEqual(section.symbol(in: j.preferences), section.defaultSymbol) }
        j.preferences.interfaceIcons = ["day": "   ", "week": "  star.fill  "]
        XCTAssertEqual(InterfaceSection.day.symbol(in: j.preferences), "sun.max")
        XCTAssertEqual(InterfaceSection.week.symbol(in: j.preferences), "star.fill")
        try Engine.validate(j)
    }
    func testIconChoicesPersistAndKeepActivityData() throws {
        var j = Journal(); let original = j
        for section in InterfaceSection.allCases { section.setSymbol("star.fill", in: &j.preferences) }
        XCTAssertEqual(j.preferences.interfaceIcons?.count, InterfaceSection.allCases.count)
        XCTAssertEqual(j.activities, original.activities); XCTAssertEqual(j.entries, original.entries)
        XCTAssertEqual(j.goals, original.goals); XCTAssertEqual(j.runtime, original.runtime)
        var restored = j.preferences; restored.interfaceIcons = nil
        XCTAssertEqual(restored, original.preferences)
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j))
        XCTAssertEqual(decoded, j)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = try Repository(url: folder.appendingPathComponent("journal.sqlite"))
        try repository.save(j); XCTAssertEqual(try repository.load(), j)
        for section in InterfaceSection.allCases { XCTAssertEqual(section.symbol(in: decoded.preferences), "star.fill") }
        try Engine.validate(j)
    }
    func testIndividualAndAllResetsPreserveUnrelatedChoices() {
        var j = Journal(); j.preferences.userName = "Tên thử"; j.preferences.sound = true
        InterfaceSection.day.setSymbol("star.fill", in: &j.preferences)
        InterfaceSection.week.setSymbol("heart.fill", in: &j.preferences)
        InterfaceSection.day.setSymbol(nil, in: &j.preferences)
        XCTAssertEqual(InterfaceSection.day.symbol(in: j.preferences), "sun.max")
        XCTAssertEqual(InterfaceSection.week.symbol(in: j.preferences), "heart.fill")
        InterfaceSection.week.setSymbol(InterfaceSection.week.defaultSymbol, in: &j.preferences)
        XCTAssertNil(j.preferences.interfaceIcons)
        InterfaceSection.goals.setSymbol("flag.fill", in: &j.preferences)
        let activities = j.activities
        j.preferences.interfaceIcons = nil
        XCTAssertEqual(j.activities, activities)
        XCTAssertEqual(j.preferences.userName, "Tên thử"); XCTAssertTrue(j.preferences.sound)
        InterfaceSection.summary.setSymbol("star.fill", in: &j.preferences)
        j.reset(); XCTAssertNil(j.preferences.interfaceIcons)
    }
}

import Foundation
import NhipCore

final class PeriodNavigationTests {
    let calendar = Preferences().calendar
    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
    func testWeekPickerUsesWeekYearAtNewYear() {
        let january1 = date(2021, 1, 1)
        XCTAssertEqual(calendar.component(.yearForWeekOfYear, from: january1), 2020)
        XCTAssertEqual(calendar.component(.weekOfYear, from: january1), 53)
        let selected = PeriodNavigation.weekDate(year: 2020, week: 53, calendar: calendar)
        XCTAssertEqual(calendar.component(.weekday, from: selected), 2)
        XCTAssertEqual(calendar.component(.year, from: selected), 2020)
        XCTAssertEqual(calendar.component(.month, from: selected), 12)
        XCTAssertEqual(calendar.component(.day, from: selected), 28)
    }
    func testChangingWeekYearClampsWeek53() {
        XCTAssertEqual(PeriodNavigation.weeks(in: 2020, calendar: calendar), 53)
        XCTAssertEqual(PeriodNavigation.weeks(in: 2021, calendar: calendar), 52)
        let selected = PeriodNavigation.weekDate(year: 2021, week: 53, calendar: calendar)
        XCTAssertEqual(calendar.component(.yearForWeekOfYear, from: selected), 2021)
        XCTAssertEqual(calendar.component(.weekOfYear, from: selected), 52)
    }
    func testMonthAndYearSelectionNormalizeToFirstDay() {
        let leapFebruary = PeriodNavigation.monthDate(year: 2024, month: 2, calendar: calendar)
        let regularFebruary = PeriodNavigation.monthDate(year: 2025, month: 2, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: leapFebruary), 1)
        XCTAssertEqual(calendar.component(.hour, from: leapFebruary), 0)
        XCTAssertEqual(calendar.range(of: .day, in: .month, for: leapFebruary)?.count, 29)
        XCTAssertEqual(calendar.range(of: .day, in: .month, for: regularFebruary)?.count, 28)
        let year = PeriodNavigation.monthDate(year: 2026, month: 1, calendar: calendar)
        XCTAssertEqual(calendar.component(.year, from: year), 2026)
        XCTAssertEqual(calendar.component(.month, from: year), 1)
        XCTAssertEqual(calendar.component(.day, from: year), 1)
    }
    func testPeriodArrowsAdvanceWholePeriodsAtBoundaries() {
        let nextMonth = PeriodNavigation.move(.month, from: date(2025, 1, 31), by: 1, calendar: calendar)
        XCTAssertEqual(calendar.component(.month, from: nextMonth), 2)
        XCTAssertEqual(calendar.component(.day, from: nextMonth), 1)
        let previous = PeriodNavigation.move(.month, from: nextMonth, by: -1, calendar: calendar)
        XCTAssertEqual(calendar.component(.month, from: previous), 1)
        XCTAssertEqual(calendar.component(.day, from: previous), 1)
        let nextYear = PeriodNavigation.move(.year, from: date(2024, 2, 29), by: 1, calendar: calendar)
        XCTAssertEqual(calendar.component(.year, from: nextYear), 2025)
        XCTAssertEqual(calendar.component(.month, from: nextYear), 1)
        let nextWeek = PeriodNavigation.move(.week, from: date(2021, 1, 1), by: 1, calendar: calendar)
        XCTAssertEqual(calendar.component(.yearForWeekOfYear, from: nextWeek), 2021)
        XCTAssertEqual(calendar.component(.weekOfYear, from: nextWeek), 1)
    }
}

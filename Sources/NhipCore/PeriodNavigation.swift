import Foundation

public enum PeriodNavigation {
    public static func monthDate(year: Int, month: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: min(12, max(1, month)), day: 1))!
    }
    public static func weeks(in year: Int, calendar: Calendar) -> Int {
        // Reports use Monday + four minimum days: December 28 is always in the last ISO week.
        let december28 = calendar.date(from: DateComponents(year: year, month: 12, day: 28))!
        return calendar.component(.weekOfYear, from: december28)
    }
    public static func weekDate(year: Int, week: Int, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.yearForWeekOfYear = year
        components.weekOfYear = min(weeks(in: year, calendar: calendar), max(1, week))
        components.weekday = calendar.firstWeekday
        return calendar.date(from: components)!
    }
    public static func move(_ period: ReportPeriod, from date: Date, by offset: Int, calendar: Calendar) -> Date {
        let start = calendar.dateInterval(of: period.component, for: date)!.start
        return calendar.date(byAdding: period.component, value: offset, to: start)!
    }
}

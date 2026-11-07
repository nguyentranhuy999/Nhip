import Foundation

public enum ReportPeriod: String, CaseIterable, Identifiable {
    case day = "Ngày", week = "Tuần", month = "Tháng", year = "Năm"
    public var id: String { rawValue }
    public var component: Calendar.Component { switch self { case .day: return .day; case .week: return .weekOfYear; case .month: return .month; case .year: return .year } }
}
public struct Report {
    public var range: DateInterval
    public var totals: [UUID: Double]
    public var tracked: Double
    public var classifiedTracked: Double
    public var total: Double { totals.values.reduce(0,+) }
    public var unknown: Double { max(0, tracked - classifiedTracked) }
    public var manualOutside: Double { max(0, total - classifiedTracked) }
    public var coverage: Double? { tracked > 0 ? classifiedTracked / tracked : nil }
}
public struct ChartPoint: Identifiable {
    public var id: String { "\(date.timeIntervalSince1970)-\(activityID)" }
    public var date: Date
    public var activityID: UUID
    public var seconds: Double
}
public enum Reports {
    public static func allTimeRange(_ j: Journal, now: Date = Date()) -> DateInterval {
        guard let first = j.entries.map(\.start).min(), let last = j.entries.map(\.end).max() else {
            return DateInterval(start: now, duration: 0)
        }
        return DateInterval(start: first, end: last)
    }
    public static func daysWithData(_ j: Journal, range: DateInterval) -> Int {
        let calendar = j.preferences.calendar
        var days: Set<Date> = []
        let spans = j.intervals + j.entries.map { Span(start: $0.start, end: $0.end) }
        for span in spans where span.end > range.start && span.start < range.end {
            var day = calendar.startOfDay(for: max(span.start, range.start))
            let end = min(span.end, range.end)
            while day < end {
                days.insert(day)
                day = calendar.date(byAdding: .day, value: 1, to: day)!
            }
        }
        return days.count
    }
    public static func range(_ period: ReportPeriod, date: Date, calendar: Calendar) -> DateInterval {
        calendar.dateInterval(of: period.component, for: date)!
    }
    public static func summarize(_ j: Journal, range: DateInterval, activityID: UUID? = nil) -> Report {
        let entries = j.entries.filter { $0.end > range.start && $0.start < range.end }
        let spans = j.intervals.filter { $0.end > range.start && $0.start < range.end }
        var totals: [UUID: Double] = [:]
        var classified: Double = 0
        for entry in entries {
            if activityID == nil || entry.activityID == activityID {
                totals[entry.activityID, default: 0] += overlap(entry.start, entry.end, range.start, range.end)
            }
        }
        // Both sequences are non-overlapping; sweep once instead of O(entries * intervals).
        let sortedEntries = entries.sorted { $0.start < $1.start }
        let sortedSpans = spans.sorted { $0.start < $1.start }
        var index = 0
        for span in sortedSpans {
            while index < sortedEntries.count && sortedEntries[index].end <= span.start { index += 1 }
            var cursor = index
            while cursor < sortedEntries.count && sortedEntries[cursor].start < span.end {
                let entry = sortedEntries[cursor]
                classified += overlap(max(span.start, range.start), min(span.end, range.end), entry.start, entry.end)
                cursor += 1
            }
        }
        return Report(range: range, totals: totals, tracked: spans.reduce(0) { $0 + overlap($1.start, $1.end, range.start, range.end) }, classifiedTracked: classified)
    }
    public static func points(_ j: Journal, range: DateInterval, period: ReportPeriod, activityID: UUID?) -> [ChartPoint] {
        let calendar = j.preferences.calendar
        let unit: Calendar.Component = period == .year ? .month : (period == .day ? .hour : .day)
        var cursor = range.start
        var result: [ChartPoint] = []
        while cursor < range.end {
            let end = min(calendar.date(byAdding: unit, value: 1, to: cursor)!, range.end)
            let totals = summarize(j, range: DateInterval(start: cursor, end: end), activityID: activityID).totals
            for (id, seconds) in totals where seconds > 0 { result.append(ChartPoint(date: cursor, activityID: id, seconds: seconds)) }
            cursor = end
        }
        return result.sorted { $0.date == $1.date ? $0.activityID.uuidString < $1.activityID.uuidString : $0.date < $1.date }
    }
    public static func comparisonRanges(period: ReportPeriod, date: Date, now: Date, calendar: Calendar) -> (DateInterval, DateInterval) {
        let current = range(period, date: date, calendar: calendar)
        let previous = range(period, date: calendar.date(byAdding: period.component, value: -1, to: current.start)!, calendar: calendar)
        guard current.contains(now), now > current.start else { return (current, previous) }
        let parts = calendar.dateComponents([.day, .hour, .minute, .second], from: current.start, to: now)
        var endPrevious = calendar.date(byAdding: parts, to: previous.start) ?? previous.end
        if endPrevious > previous.end {
            // Retain the clock time on the last shared day of a shorter period.
            let lastDay = calendar.date(byAdding: .day, value: -1, to: previous.end)!
            let clock = calendar.dateComponents([.hour, .minute, .second], from: now)
            endPrevious = calendar.date(bySettingHour: clock.hour ?? 0, minute: clock.minute ?? 0, second: clock.second ?? 0, of: lastDay)!
        }
        let sharedParts = calendar.dateComponents([.day, .hour, .minute, .second], from: previous.start, to: endPrevious)
        let endCurrent = min(now, calendar.date(byAdding: sharedParts, to: current.start) ?? now)
        return (DateInterval(start: current.start, end: endCurrent), DateInterval(start: previous.start, end: endPrevious))
    }
    public static func csv(_ j: Journal, range: DateInterval) -> String {
        let formatter = ISO8601DateFormatter(); formatter.timeZone = TimeZone(identifier: j.preferences.timezone)
        func quote(_ text: String) -> String { "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var rows = ["Bắt đầu,Kết thúc,Múi giờ,Phút,Hoạt động,Ghi chú,Nguồn"]
        for entry in j.entries.sorted(by: { $0.start < $1.start }) where entry.end > range.start && entry.start < range.end {
            let start = max(entry.start, range.start), end = min(entry.end, range.end)
            // Neutralize spreadsheet formulas in user-authored fields.
            func safe(_ value: String) -> String { ["=", "+", "-", "@", "\t", "\r"].contains(where: { value.hasPrefix($0) }) ? "'" + value : value }
            rows.append([formatter.string(from: start), formatter.string(from: end), j.preferences.timezone, String(format: "%.4f", end.timeIntervalSince(start)/60), safe(j.activity(entry.activityID)?.name ?? "Khác"), safe(entry.note), entry.source].map(quote).joined(separator: ","))
        }
        return "\u{FEFF}" + rows.joined(separator: "\r\n")
    }
}

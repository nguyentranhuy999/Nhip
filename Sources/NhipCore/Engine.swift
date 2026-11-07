import Foundation

public enum Engine {
    public static func start(_ j: inout Journal, at now: Date) {
        if j.runtime.enabled && j.runtime.segmentStart != nil && j.runtime.pauseUntil == nil { return }
        j.runtime.enabled = true; j.runtime.pauseUntil = nil
        if j.preferences.allows(now) { begin(&j, at: now) }
    }
    public static func begin(_ j: inout Journal, at now: Date) {
        guard !j.isRecordingPersonalActivity else { return }
        j.runtime.segmentStart = now
        let due = now.addingTimeInterval(Double(j.preferences.intervalMinutes * 60))
        j.runtime.nextDue = min(due, j.preferences.scheduleEnd(at: now) ?? due)
        j.runtime.heartbeat = now
    }
    @discardableResult public static func tick(_ j: inout Journal, at now: Date) -> [Span] {
        guard j.runtime.enabled, !j.isRecordingPersonalActivity else { return [] }
        if let pause = j.runtime.pauseUntil {
            guard now >= pause else { return [] }
            j.runtime.pauseUntil = nil
        }
        var completed: [Span] = []
        while let start = j.runtime.segmentStart, let due = j.runtime.nextDue, due <= now {
            if due > start {
                let span = Span(start: start, end: due)
                j.intervals.append(span); completed.append(span)
            }
            j.runtime.segmentStart = nil; j.runtime.nextDue = nil
            guard j.preferences.allows(due) else { break }
            begin(&j, at: due)
            // Bound unexpected clock jumps; application lifecycle normally prevents these.
            if completed.count >= 288 { break }
        }
        if !j.preferences.allows(now) {
            close(&j, at: now)
        } else if j.runtime.segmentStart == nil { begin(&j, at: now) }
        j.runtime.heartbeat = now
        return completed
    }
    public static func close(_ j: inout Journal, at now: Date) {
        if let start = j.runtime.segmentStart, now > start {
            let end = min(now, j.runtime.nextDue ?? now)
            if end > start { j.intervals.append(Span(start: start, end: end)) }
        }
        j.runtime.segmentStart = nil; j.runtime.nextDue = nil; j.runtime.heartbeat = now
    }
    public static func recover(_ j: inout Journal) {
        // Only retain time known to have been alive, never the whole offline gap.
        if let last = j.runtime.heartbeat {
            _ = tick(&j, at: last)
            close(&j, at: last)
        }
        j.runtime.segmentStart = nil; j.runtime.nextDue = nil
    }
    public static func pause(_ j: inout Journal, at now: Date, minutes: Int?) {
        _ = tick(&j, at: now); close(&j, at: now)
        j.runtime.enabled = minutes != nil
        j.runtime.pauseUntil = minutes.map { now.addingTimeInterval(Double($0 * 60)) }
    }
    public static func unanswered(_ j: Journal, in interval: Span) -> [Span] {
        var cursor = interval.start
        var result: [Span] = []
        let entries = j.entries.filter { $0.end > interval.start && $0.start < interval.end }.sorted { $0.start < $1.start }
        for e in entries {
            let begin = max(interval.start, e.start)
            if begin > cursor { result.append(Span(start: cursor, end: begin)) }
            cursor = max(cursor, min(interval.end, e.end))
        }
        if cursor < interval.end { result.append(Span(start: cursor, end: interval.end)) }
        return result
    }
    public static func isAnswered(_ j: Journal, interval: Span) -> Bool { unanswered(j, in: interval).isEmpty }
    public static func recentCheckIn(_ j: Journal, at now: Date) -> Span? {
        guard !j.isRecordingPersonalActivity else { return nil }
        guard let latest = j.intervals.max(by: { $0.end < $1.end }),
              now >= latest.end,
              now.timeIntervalSince(latest.end) < Double(j.preferences.intervalMinutes * 60),
              !j.skipped.contains(latest.id),
              !isAnswered(j, interval: latest) else { return nil }
        // Never fall back to an older missed interval: the user only answers the latest one.
        return latest
    }
    public static func pendingIntervals(_ j: Journal) -> [Span] {
        let entries = j.entries.sorted { $0.start < $1.start }
        var index = 0
        var result: [Span] = []
        for span in j.intervals.sorted(by: { $0.start < $1.start }) {
            while index < entries.count && entries[index].end <= span.start { index += 1 }
            var cursor = span.start, scan = index
            while scan < entries.count && entries[scan].start <= cursor && cursor < span.end {
                cursor = max(cursor, entries[scan].end); scan += 1
            }
            if cursor < span.end { result.append(span) }
        }
        return result.reversed()
    }
    public static func record(_ j: inout Journal, entry: Entry, replacing: Bool = false) throws {
        guard entry.end > entry.start else { throw JournalError.invalid("Giờ kết thúc phải sau giờ bắt đầu.") }
        guard entry.end <= Date().addingTimeInterval(1) else { throw JournalError.invalid("Không thể ghi nhận thời gian trong tương lai.") }
        guard j.activity(entry.activityID) != nil else { throw JournalError.invalid("Hoạt động không tồn tại.") }
        let conflicts = j.entries.filter { $0.id != entry.id && overlap($0.start, $0.end, entry.start, entry.end) > 0 }
        guard replacing || conflicts.isEmpty else { throw JournalError.invalid("Khoảng này chồng lên dữ liệu đã có. Bật ‘Thay thế phần chồng lấn’ để xác nhận.") }
        var next = j.entries.filter { $0.id != entry.id && !conflicts.contains($0) }
        if replacing {
            for old in conflicts {
                if old.start < entry.start {
                    var left = old; left.end = entry.start; left.updatedAt = Date(); next.append(left)
                }
                if old.end > entry.end {
                    var right = old; right.id = UUID(); right.start = entry.end; right.updatedAt = Date(); next.append(right)
                }
            }
        }
        var changed = entry; changed.updatedAt = Date()
        next.append(changed); j.entries = next.sorted { $0.start < $1.start }
        j.runtime.lastActivityID = entry.activityID
    }
    public static func answer(_ j: inout Journal, intervalID: UUID, activityID: UUID, note: String = "") throws {
        guard let interval = j.intervals.first(where: { $0.id == intervalID }) else { throw JournalError.invalid("Không tìm thấy khoảng thời gian.") }
        let gaps = unanswered(j, in: interval)
        guard !gaps.isEmpty else { return }
        var draft = j
        for gap in gaps { try record(&draft, entry: Entry(start: gap.start, end: gap.end, activityID: activityID, note: note, source: "checkin")) }
        draft.skipped.removeAll { $0 == intervalID }; j = draft
    }
    public static func validate(_ j: Journal) throws {
        try PersonalTracking.validate(j)
        try SleepTracking.validate(j.sleepHistory, journal: j)
        try SleepPlan.validate(j.sleepReminders)
        guard j.schemaVersion == 1 else { throw JournalError.invalid("Phiên bản sao lưu không được hỗ trợ.") }
        guard [5,10,15,30,60].contains(j.preferences.intervalMinutes), TimeZone(identifier: j.preferences.timezone) != nil else { throw JournalError.invalid("Cài đặt chu kỳ hoặc múi giờ không hợp lệ.") }
        guard !j.activities.isEmpty, Set(j.activities.map(\.id)).count == j.activities.count,
              j.activities.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.color.count == 6 && UInt32($0.color, radix: 16) != nil }) else { throw JournalError.invalid("Danh mục không hợp lệ.") }
        guard Set(j.entries.map(\.id)).count == j.entries.count, Set(j.intervals.map(\.id)).count == j.intervals.count else { throw JournalError.invalid("Trùng ID trong bản sao lưu.") }
        for window in j.preferences.windows {
            guard (1...7).contains(window.weekday), window.startMinute >= 0, window.endMinute <= 1440, window.startMinute < window.endMinute else { throw JournalError.invalid("Lịch theo dõi không hợp lệ.") }
        }
        let sorted = j.entries.sorted { $0.start < $1.start }
        for (index, e) in sorted.enumerated() {
            guard e.start.timeIntervalSince1970.isFinite, e.end.timeIntervalSince1970.isFinite, e.end > e.start, j.activity(e.activityID) != nil else { throw JournalError.invalid("Bản ghi không hợp lệ.") }
            if index > 0 && sorted[index - 1].end > e.start { throw JournalError.invalid("Bản sao lưu có thời gian chồng lấn.") }
        }
        let spans = j.intervals.sorted { $0.start < $1.start }
        for (index, span) in spans.enumerated() {
            guard span.start.timeIntervalSince1970.isFinite, span.end.timeIntervalSince1970.isFinite, span.end > span.start,
                  index == 0 || spans[index - 1].end <= span.start else { throw JournalError.invalid("Khoảng theo dõi không hợp lệ hoặc chồng lấn.") }
        }
        guard Set(j.goals.map(\.id)).count == j.goals.count else { throw JournalError.invalid("Trùng ID mục tiêu.") }
        let dailyGoals = j.goals.filter(\.isDaily)
        guard Set(dailyGoals.map(\.activityID)).count == dailyGoals.count else { throw JournalError.invalid("Mỗi hoạt động chỉ có một mục tiêu hằng ngày.") }
        for goal in j.goals {
            guard j.activity(goal.activityID) != nil, ["increase", "limit", "observe"].contains(goal.direction), goal.minutes >= 0,
                  ["day", "week"].contains(goal.periodName), goal.effectiveFrom.timeIntervalSince1970.isFinite else { throw JournalError.invalid("Mục tiêu không hợp lệ.") }
            if goal.isDaily && (!(1...1440).contains(goal.minutes) || goal.direction != "increase") { throw JournalError.invalid("Mục tiêu mỗi ngày phải từ 1 phút đến 24 giờ.") }
        }
    }
}

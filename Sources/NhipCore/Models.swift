import Foundation

public struct Activity: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var color: String
    public var symbol: String
    public var archived: Bool
    public var personalKind: PersonalActivityKind?
    public var personalKindResolved: Bool? // An explicit nil role must survive cosmetic edits.
    public var recordingMode: ActivityRecordingMode?
    public var isPriority: Bool? // Missing in older journals means unselected.
    public init(id: UUID = UUID(), name: String, color: String, symbol: String = "circle.fill", archived: Bool = false, personalKind: PersonalActivityKind? = nil, recordingMode: ActivityRecordingMode? = nil, isPriority: Bool? = nil) {
        self.id = id; self.name = name; self.color = color; self.symbol = symbol; self.archived = archived
        self.personalKind = personalKind
        self.recordingMode = recordingMode
        self.isPriority = isPriority
    }
    public static var defaults: [Activity] {
        func activity(_ name: String, color: String, symbol: String, kind: PersonalActivityKind? = nil,
                      mode: ActivityRecordingMode = .both, priority: Bool = false) -> Activity {
            var value = Activity(name: name, color: color, symbol: symbol, personalKind: kind,
                                 recordingMode: mode, isPriority: priority)
            value.personalKindResolved = true
            return value
        }
        return [
            activity("Học tập", color: "6366F1", symbol: "book.fill", priority: true),
            activity("Nghiên cứu", color: "0EA5A4", symbol: "magnifyingglass", priority: true),
            activity("Thể thao", color: "F59E0B", symbol: "figure.flexibility", kind: .exercise, mode: .manual, priority: true),
            activity("Giải trí", color: "EC4899", symbol: "gamecontroller.fill"),
            activity("Công việc", color: "3B82F6", symbol: "briefcase.fill", priority: true),
            activity("Sinh hoạt cá nhân", color: "A78BFA", symbol: "house.fill", kind: .personal, mode: .manual),
            activity("Ngủ", color: "84A65B", symbol: "bed.double.fill", kind: .rest, mode: .manual, priority: true),
            activity("Khác", color: "94A3B8", symbol: "ellipsis.circle.fill"),
            activity("Nghỉ ngơi", color: "EF4444", symbol: "cup.and.saucer.fill")
        ]
    }
}

public struct Span: Codable, Identifiable, Equatable {
    public var id: UUID
    public var start: Date
    public var end: Date
    public init(id: UUID = UUID(), start: Date, end: Date) { self.id = id; self.start = start; self.end = end }
    public var seconds: Double { max(0, end.timeIntervalSince(start)) }
}

public struct Entry: Codable, Identifiable, Equatable {
    public var id: UUID
    public var start: Date
    public var end: Date
    public var activityID: UUID
    public var note: String
    public var source: String
    public var updatedAt: Date
    public init(id: UUID = UUID(), start: Date, end: Date, activityID: UUID, note: String = "", source: String = "manual") {
        self.id = id; self.start = start; self.end = end; self.activityID = activityID
        self.note = note; self.source = source; self.updatedAt = Date()
    }
    public var seconds: Double { max(0, end.timeIntervalSince(start)) }
}

public struct Goal: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var activityID: UUID
    public var direction: String // increase, limit, observe
    public var minutes: Int
    public var effectiveFrom: Date
    public var period: String? // Missing in older backups means a weekly goal.
    public var periodName: String { period ?? "week" }
    public var isDaily: Bool { periodName == "day" }
    public init(activityID: UUID, direction: String, minutes: Int, effectiveFrom: Date, period: String = "week") {
        self.activityID = activityID; self.direction = direction; self.minutes = minutes; self.effectiveFrom = effectiveFrom; self.period = period
    }
}

public struct ScheduleWindow: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var weekday: Int // Calendar weekday: Sunday=1
    public var startMinute: Int
    public var endMinute: Int
    public init(weekday: Int, startMinute: Int = 8 * 60, endMinute: Int = 22 * 60) {
        self.weekday = weekday; self.startMinute = startMinute; self.endMinute = endMinute
    }
}

public struct Preferences: Codable, Equatable {
    public var userName: String? // Missing in older journals: use the macOS account name.
    public var interfaceIcons: [String: String]? // Missing in older journals: default navigation icons.
    public var interfaceTitles: [String: String]? // Missing in older journals: default navigation titles.
    public var dashboardActivities: [String: [UUID]]? // Stable selections for day/week/month/year/summary.
    public var intervalMinutes = 5
    public var timezone = "Asia/Ho_Chi_Minh"
    public var sound = true
    public var checkInSuccessSound: Bool? // Missing in older journals: confirmation sound enabled.
    public var isCheckInSuccessSoundEnabled: Bool { checkInSuccessSound ?? true }
    public var scheduled = false
    public var windows: [ScheduleWindow] = []
    public var onboarded = false
    public init() {}
    public var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: timezone) ?? .current
        c.firstWeekday = 2; c.minimumDaysInFirstWeek = 4
        return c
    }
    public func allows(_ date: Date) -> Bool {
        guard scheduled else { return true }
        let c = calendar
        let minute = c.component(.hour, from: date) * 60 + c.component(.minute, from: date)
        let day = c.component(.weekday, from: date)
        return windows.contains { $0.weekday == day && minute >= $0.startMinute && minute < $0.endMinute }
    }
    public func scheduleEnd(at date: Date) -> Date? {
        guard scheduled else { return nil }
        let c = calendar
        let minute = c.component(.hour, from: date) * 60 + c.component(.minute, from: date)
        let day = c.component(.weekday, from: date)
        let matching = windows.filter { $0.weekday == day && minute >= $0.startMinute && minute < $0.endMinute }
        guard let last = matching.map(\.endMinute).max() else { return nil }
        return c.date(byAdding: .minute, value: last, to: c.startOfDay(for: date))
    }
}

public struct Runtime: Codable, Equatable {
    public var enabled = false
    public var segmentStart: Date?
    public var nextDue: Date?
    public var heartbeat: Date?
    public var pauseUntil: Date?
    public var lastActivityID: UUID?
    public init() {}
}

public struct Journal: Codable, Equatable {
    public var schemaVersion = 1
    public var activities = Activity.defaults
    public var intervals: [Span] = []
    public var entries: [Entry] = []
    public var skipped: [UUID] = []
    public var goals: [Goal] = []
    public var sleepReminders: SleepReminderState? // Absent in older data: use the default daily plan.
    public var sleepHistory: SleepHistory?
    public var personalHistory: PersonalActivityHistory?
    public var preferences = Preferences()
    public var runtime = Runtime()
    public init() {}
    public mutating func reset(at now: Date = Date()) {
        self = Journal()
        SleepPlan.prepareStatistics(journal: &self, on: now)
    }
    public func activity(_ id: UUID) -> Activity? { activities.first { $0.id == id } }
    public var isRecordingPersonalActivity: Bool { sleepHistory?.active != nil || personalHistory?.active != nil }
}

public enum JournalError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

public func overlap(_ a: Date, _ b: Date, _ c: Date, _ d: Date) -> Double {
    max(0, min(b, d).timeIntervalSince(max(a, c)))
}

public func durationText(_ seconds: Double) -> String {
    let minutes = max(0, Int(seconds / 60))
    if minutes == 0 && seconds > 0 { return "< 1 phút" }
    if minutes < 60 { return "\(minutes) phút" }
    return minutes % 60 == 0 ? "\(minutes / 60) giờ" : "\(minutes / 60) giờ \(minutes % 60) phút"
}

import Foundation

public enum PersonalActivityKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case exercise, personal, rest
    public var id: String { rawValue }
    public static var timedKinds: [Self] { [.exercise, .personal] }
    public var title: String {
        switch self { case .exercise: return "Tập thể thao"; case .personal: return "Sinh hoạt cá nhân"; case .rest: return "Nghỉ ngơi" }
    }
    public var symbol: String {
        switch self { case .exercise: return "figure.run"; case .personal: return "house.fill"; case .rest: return "cup.and.saucer.fill" }
    }
    public var color: String {
        switch self { case .exercise: return "F59E0B"; case .personal: return "0EA5A4"; case .rest: return "84A65B" }
    }
}

public struct PersonalActivitySession: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var kind: PersonalActivityKind
    public var activityID: UUID
    public var start: Date
    public var end: Date?
    public var entryID: UUID?
}

public struct PersonalActivityHistory: Codable, Equatable {
    public var sessions: [PersonalActivitySession] = []
    public init() {}
    public var active: PersonalActivitySession? { sessions.first { $0.end == nil } }
}

public enum PersonalTracking {
    public static func kind(of activity: Activity) -> PersonalActivityKind? {
        activity.personalKind ?? PersonalActivityKind.allCases.first { activity.name == $0.title || activity.symbol == $0.symbol }
    }
    public static func quickActivities(_ journal: Journal) -> [Activity] {
        journal.activities.filter { !$0.archived && kind(of: $0) == nil && $0.id != journal.sleepHistory?.restActivityID }
    }
    /// Add stable category roles to old data without rewriting entries or goals.
    public static func prepare(_ journal: inout Journal) {
        for index in journal.activities.indices where journal.activities[index].personalKind == nil {
            if journal.activities[index].id == journal.sleepHistory?.restActivityID { journal.activities[index].personalKind = .rest }
            else { journal.activities[index].personalKind = kind(of: journal.activities[index]) }
        }
    }
    @discardableResult public static func start(_ journal: inout Journal, kind: PersonalActivityKind, at now: Date) throws -> UUID {
        guard kind != .rest, now.timeIntervalSince1970.isFinite, now <= Date().addingTimeInterval(1) else {
            throw JournalError.invalid("Loại hoạt động hoặc giờ bắt đầu không hợp lệ.")
        }
        guard !journal.isRecordingPersonalActivity else { throw JournalError.invalid("Hãy kết thúc hoạt động đang ghi nhận trước.") }
        var draft = journal; prepare(&draft)
        _ = Engine.tick(&draft, at: now); Engine.close(&draft, at: now)
        let matching = draft.activities.filter { Self.kind(of: $0) == kind }
        let activity: Activity
        if let existing = matching.first(where: { !$0.archived }) ?? matching.first { activity = existing }
        else {
            activity = Activity(name: kind.title, color: kind.color, symbol: kind.symbol, personalKind: kind)
            draft.activities.append(activity)
        }
        let session = PersonalActivitySession(kind: kind, activityID: activity.id, start: now)
        if draft.personalHistory == nil { draft.personalHistory = PersonalActivityHistory() }
        draft.personalHistory?.sessions.append(session)
        try Engine.validate(draft); journal = draft; return session.id
    }
    @discardableResult public static func finish(_ journal: inout Journal, kind: PersonalActivityKind, at now: Date, start: Date? = nil, resumeAt: Date? = nil) throws -> UUID {
        guard let active = journal.personalHistory?.active, active.kind == kind else { throw JournalError.invalid("Hoạt động này chưa được bắt đầu.") }
        let entry = Entry(start: start ?? active.start, end: now, activityID: active.activityID, source: "personal-timer")
        var draft = journal
        try Engine.record(&draft, entry: entry)
        let index = draft.personalHistory!.sessions.firstIndex { $0.id == active.id }!
        draft.personalHistory?.sessions[index].start = entry.start
        draft.personalHistory?.sessions[index].end = now; draft.personalHistory?.sessions[index].entryID = entry.id
        _ = Engine.tick(&draft, at: resumeAt ?? now)
        try Engine.validate(draft); journal = draft; return active.id
    }
    public static func edit(_ journal: inout Journal, sessionID: UUID, start: Date, end: Date) throws {
        guard let index = journal.personalHistory?.sessions.firstIndex(where: { $0.id == sessionID }),
              journal.personalHistory?.sessions[index].end != nil,
              let entryID = journal.personalHistory?.sessions[index].entryID,
              var entry = journal.entries.first(where: { $0.id == entryID }) else {
            throw JournalError.invalid("Không tìm thấy hoạt động đã kết thúc để sửa giờ.")
        }
        var draft = journal
        entry.start = start; entry.end = end
        try Engine.record(&draft, entry: entry)
        draft.personalHistory?.sessions[index].start = start; draft.personalHistory?.sessions[index].end = end
        draft.personalHistory?.sessions[index].activityID = entry.activityID
        try Engine.validate(draft); journal = draft
    }
    public static func delete(_ journal: inout Journal, sessionID: UUID, at now: Date) throws {
        guard let session = journal.personalHistory?.sessions.first(where: { $0.id == sessionID }) else { return }
        var draft = journal
        draft.personalHistory?.sessions.removeAll { $0.id == sessionID }
        draft.entries.removeAll { $0.id == session.entryID && $0.source == "personal-timer" }
        if session.end == nil { _ = Engine.tick(&draft, at: now) }
        try Engine.validate(draft); journal = draft
    }
    public static func validate(_ journal: Journal) throws {
        guard let history = journal.personalHistory else { return }
        let linked = history.sessions.compactMap(\.entryID)
        guard Set(history.sessions.map(\.id)).count == history.sessions.count,
              Set(linked).count == linked.count, history.sessions.filter({ $0.end == nil }).count <= 1,
              !(history.active != nil && journal.sleepHistory?.active != nil) else {
            throw JournalError.invalid("Dữ liệu hoạt động cá nhân bị trùng hoặc đang ghi nhận hai phiên cùng lúc.")
        }
        let sorted = history.sessions.sorted { $0.start < $1.start }
        for (index, session) in sorted.enumerated() {
            guard session.kind != .rest, journal.activity(session.activityID) != nil, session.start.timeIntervalSince1970.isFinite,
                  session.end.map({ $0.timeIntervalSince1970.isFinite && $0 > session.start && session.entryID != nil }) ?? (session.entryID == nil),
                  index == 0 || (sorted[index - 1].end.map { $0 <= session.start } ?? false) else {
                throw JournalError.invalid("Thời gian hoạt động cá nhân không hợp lệ hoặc chồng lấn.")
            }
        }
    }
}

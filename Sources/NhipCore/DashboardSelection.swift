import Foundation

public enum DashboardPage: String, CaseIterable, Identifiable {
    case day, week, month, year, summary
    public var id: String { rawValue }
    public init(period: ReportPeriod) {
        switch period { case .day: self = .day; case .week: self = .week; case .month: self = .month; case .year: self = .year }
    }
    public func title(in preferences: Preferences) -> String {
        InterfaceSection(rawValue: rawValue)!.title(in: preferences)
    }
}

public enum DashboardSelection {
    public static let maximum = 6
    public static func defaultIDs(_ journal: Journal) -> [UUID] {
        let active = journal.activities.filter { !$0.archived }
        let preferred = active.filter { $0.isPriority == true }
        let candidates = preferred + active.filter { $0.isPriority != true }
        return Array(candidates.prefix(3).map(\.id))
    }
    public static func selectedIDs(for page: DashboardPage, journal: Journal) -> [UUID] {
        journal.preferences.dashboardActivities?[page.rawValue] ?? defaultIDs(journal)
    }
    // Materialize defaults once so later renames, reordering, or priority changes cannot change a page's selection.
    public static func prepare(_ journal: inout Journal) {
        var pages = journal.preferences.dashboardActivities ?? [:]
        let defaults = defaultIDs(journal)
        for page in DashboardPage.allCases where pages[page.rawValue] == nil { pages[page.rawValue] = defaults }
        journal.preferences.dashboardActivities = pages
    }
    public static func setSelected(_ ids: [UUID], for page: DashboardPage, journal: inout Journal) throws {
        try validateIDs(ids, journal: journal)
        var pages = journal.preferences.dashboardActivities ?? [:]
        pages[page.rawValue] = ids
        journal.preferences.dashboardActivities = pages
    }
    private static func validateIDs(_ ids: [UUID], journal: Journal) throws {
        guard ids.count <= maximum else { throw JournalError.invalid("Mỗi dashboard chỉ được chọn tối đa \(maximum) hoạt động.") }
        let existing = Set(journal.activities.map(\.id))
        guard Set(ids).count == ids.count, ids.allSatisfy({ existing.contains($0) }) else {
            throw JournalError.invalid("Lựa chọn dashboard bị trùng hoặc có hoạt động không còn tồn tại.")
        }
    }
    public static func validate(_ journal: Journal) throws {
        for (key, ids) in journal.preferences.dashboardActivities ?? [:] {
            guard DashboardPage(rawValue: key) != nil else { throw JournalError.invalid("Mục dashboard không hợp lệ.") }
            try validateIDs(ids, journal: journal)
        }
    }
}

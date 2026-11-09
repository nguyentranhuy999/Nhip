import Foundation

public enum InterfaceSection: String, CaseIterable, Identifiable {
    case day, goals, personal, week, month, year, summary, settings
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .day: return "Ngày"
        case .week: return "Tuần"
        case .month: return "Tháng"
        case .year: return "Năm"
        case .summary: return "Tổng kết"
        case .goals: return "Mục tiêu"
        case .personal: return "Hoạt động"
        case .settings: return "Cài đặt"
        }
    }
    public init(period: ReportPeriod) {
        switch period { case .day: self = .day; case .week: self = .week; case .month: self = .month; case .year: self = .year }
    }
    public func customTitle(in preferences: Preferences) -> String? {
        let value = Self.normalizedTitle(preferences.interfaceTitles?[rawValue] ?? "")
        return value.isEmpty || value == title ? nil : value
    }
    public func title(in preferences: Preferences) -> String {
        customTitle(in: preferences) ?? title
    }
    public func setTitle(_ value: String?, in preferences: inout Preferences) {
        var names = preferences.interfaceTitles ?? [:]
        let value = Self.normalizedTitle(value ?? "")
        if value.isEmpty || value == title { names.removeValue(forKey: rawValue) }
        else { names[rawValue] = value }
        preferences.interfaceTitles = names.isEmpty ? nil : names
    }
    private static func normalizedTitle(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
    public var defaultSymbol: String {
        switch self {
        case .day: return "sun.max"
        case .week: return "calendar"
        case .month: return "square.grid.3x3"
        case .year: return "chart.xyaxis.line"
        case .summary: return "sum"
        case .goals: return "target"
        case .personal: return "figure.walk"
        case .settings: return "slider.horizontal.3"
        }
    }
    public func symbol(in preferences: Preferences) -> String {
        let value = preferences.interfaceIcons?[rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? defaultSymbol : value
    }
    public func setSymbol(_ symbol: String?, in preferences: inout Preferences) {
        var icons = preferences.interfaceIcons ?? [:]
        let value = symbol?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty || value == defaultSymbol { icons.removeValue(forKey: rawValue) }
        else { icons[rawValue] = value }
        preferences.interfaceIcons = icons.isEmpty ? nil : icons
    }
}

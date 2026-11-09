import Foundation

public enum ActivityCatalog {
    public static func normalizedName(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
    private static func key(_ name: String) -> String {
        normalizedName(name).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "vi_VN"))
            .lowercased().replacingOccurrences(of: "đ", with: "d")
    }
    public static func validateName(_ name: String, in journal: Journal, excluding id: UUID? = nil) throws -> String {
        let name = normalizedName(name)
        guard !name.isEmpty else { throw JournalError.invalid("Hãy nhập tên hoạt động.") }
        if let existing = journal.activities.first(where: { $0.id != id && key($0.name) == key(name) }) {
            if existing.archived {
                throw JournalError.invalid("Hoạt động “\(existing.name)” đã có trong danh sách lưu trữ. Hãy khôi phục hoạt động đó hoặc chọn tên khác.")
            }
            throw JournalError.invalid("Đã có hoạt động “\(existing.name)”. Hãy dùng hoạt động đó hoặc chọn tên khác.")
        }
        return name
    }
    @discardableResult public static func add(_ journal: inout Journal, name: String) throws -> UUID {
        let name = try validateName(name, in: journal)
        var activity = Activity(name: name, color: "6366F1")
        // User-created activities never acquire a special role from their name or icon.
        activity.personalKindResolved = true
        var draft = journal; draft.activities.append(activity)
        try Engine.validate(draft); journal = draft
        return activity.id
    }
    public static func update(_ journal: inout Journal, activity: Activity) throws {
        guard let index = journal.activities.firstIndex(where: { $0.id == activity.id }) else {
            throw JournalError.invalid("Không tìm thấy hoạt động để sửa.")
        }
        var updated = activity
        updated.name = try validateName(activity.name, in: journal, excluding: activity.id)
        PersonalTracking.preserveRole(of: journal.activities[index], in: &updated)
        var draft = journal; draft.activities[index] = updated
        try Engine.validate(draft); journal = draft
    }
    // Internal system-created categories need a unique display name as well.
    static func availableName(_ preferred: String, in journal: Journal) -> String {
        let names = Set(journal.activities.map { key($0.name) })
        if !names.contains(key(preferred)) { return preferred }
        var suffix = 2
        while names.contains(key("\(preferred) (\(suffix))")) { suffix += 1 }
        return "\(preferred) (\(suffix))"
    }
}

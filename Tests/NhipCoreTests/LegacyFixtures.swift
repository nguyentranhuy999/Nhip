import NhipCore

// Historical journals used by the existing regressions. These predate the 1.18 preset;
// new-install and reset behavior is exercised separately in DefaultConfigurationTests.
func legacyJournal() -> Journal {
    var journal = Journal()
    journal.activities = [
        Activity(name: "Học", color: "6366F1", symbol: "book.fill"),
        Activity(name: "Nghiên cứu", color: "0EA5A4", symbol: "magnifyingglass"),
        Activity(name: "Tập thể thao", color: "F59E0B", symbol: "figure.run", personalKind: .exercise),
        Activity(name: "Giải trí", color: "EC4899", symbol: "gamecontroller.fill"),
        Activity(name: "Công việc", color: "3B82F6", symbol: "briefcase.fill"),
        Activity(name: "Sinh hoạt cá nhân", color: "A78BFA", symbol: "house.fill", personalKind: .personal),
        Activity(name: "Nghỉ ngơi", color: "84A65B", symbol: "cup.and.saucer.fill", personalKind: .rest),
        Activity(name: "Khác", color: "94A3B8", symbol: "ellipsis.circle.fill")
    ]
    journal.preferences.sound = false
    return journal
}

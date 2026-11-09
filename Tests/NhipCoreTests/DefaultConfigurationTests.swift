import Foundation
import NhipCore

final class DefaultConfigurationTests {
    private let base = ISO8601DateFormatter().date(from: "2025-11-07T02:00:00Z")! // 09:00 Vietnam.
    private let names = ["Học tập", "Nghiên cứu", "Thể thao", "Giải trí", "Công việc", "Sinh hoạt cá nhân", "Ngủ", "Khác", "Nghỉ ngơi"]
    func testNewJournalUsesConfiguredActivitiesAndNoPersonalData() throws {
        let j = Journal()
        XCTAssertEqual(j.activities.map(\.name), names)
        XCTAssertEqual(j.activities.map(\.symbol), ["book.fill", "magnifyingglass", "figure.flexibility", "gamecontroller.fill", "briefcase.fill", "house.fill", "bed.double.fill", "ellipsis.circle.fill", "cup.and.saucer.fill"])
        XCTAssertEqual(j.activities.map(\.color), ["6366F1", "0EA5A4", "F59E0B", "EC4899", "3B82F6", "A78BFA", "84A65B", "94A3B8", "EF4444"])
        XCTAssertEqual(j.activities.filter { $0.isPriority == true }.map(\.name), ["Học tập", "Nghiên cứu", "Thể thao", "Công việc", "Ngủ"])
        XCTAssertTrue(j.activities.allSatisfy { $0.personalKindResolved == true && !$0.archived })
        XCTAssertNil(j.preferences.userName); XCTAssertFalse(j.preferences.onboarded); XCTAssertFalse(j.runtime.enabled)
        XCTAssertTrue(j.entries.isEmpty); XCTAssertTrue(j.intervals.isEmpty); XCTAssertTrue(j.goals.isEmpty)
        XCTAssertNil(j.sleepHistory); XCTAssertNil(j.personalHistory)
        let ids = Set(j.activities.map(\.id))
        XCTAssertEqual(ids.count, 9); XCTAssertTrue(ids.isDisjoint(with: Journal().activities.map(\.id)))
        try Engine.validate(j)
    }
    func testReminderAudioScheduleAndNavigationDefaultsMatchPreset() throws {
        let j = Journal()
        XCTAssertTrue(j.preferences.sound); XCTAssertTrue(j.preferences.isCheckInSuccessSoundEnabled)
        XCTAssertEqual(j.preferences.intervalMinutes, 5); XCTAssertEqual(j.preferences.timezone, "Asia/Ho_Chi_Minh")
        XCTAssertFalse(j.preferences.scheduled); XCTAssertTrue(j.preferences.windows.isEmpty)
        XCTAssertTrue(SleepPlan.isEnabled(j))
        XCTAssertEqual(SleepReminder.allCases.map { SleepPlan.schedule(j).timeLabel(for: $0) }, ["00:00", "07:00", "12:30", "13:30"])
        XCTAssertEqual(InterfaceSection.week.symbol(in: j.preferences), "7.calendar")
        XCTAssertEqual(InterfaceSection.month.symbol(in: j.preferences), "30.calendar")
        XCTAssertEqual(InterfaceSection.year.symbol(in: j.preferences), "chart.bar")
        XCTAssertEqual(InterfaceSection.personal.symbol(in: j.preferences), "chart.bar.horizontal.page")
        XCTAssertEqual(InterfaceSection.personal.fallbackSymbol, "figure.walk")
        try Engine.validate(j)
    }
    func testDefaultDashboardsUseThreePresetActivitiesWithFreshIDs() throws {
        var j = Journal(); DashboardSelection.prepare(&j)
        for page in DashboardPage.allCases {
            let ids = DashboardSelection.selectedIDs(for: page, journal: j)
            XCTAssertEqual(ids.compactMap { j.activity($0)?.name }, Array(names.prefix(3)))
            XCTAssertEqual(ids, Array(j.activities.prefix(3).map(\.id)))
        }
        try Engine.validate(j)
    }
    func testDefaultRecordingModesKeepSleepAndOrdinaryRestSeparate() throws {
        let j = Journal()
        XCTAssertEqual(j.activities.map { PersonalTracking.recordingMode(of: $0) }, [.both, .both, .manual, .both, .both, .manual, .manual, .both, .both])
        XCTAssertEqual(PersonalTracking.quickActivities(j).map(\.name), ["Học tập", "Nghiên cứu", "Giải trí", "Công việc", "Khác", "Nghỉ ngơi"])
        XCTAssertEqual(PersonalTracking.manualActivities(j).count, 8)
        XCTAssertEqual(j.activities.filter { PersonalTracking.isRest($0, journal: j) }.map(\.name), ["Ngủ"])
        XCTAssertNil(PersonalTracking.kind(of: j.activities[8]))
        try Engine.validate(j)
    }
    func testNewPresetRecordsQuickManualAndSleepWithoutMixingData() throws {
        var j = Journal(); DashboardSelection.prepare(&j)
        let span = Span(start: base, end: base.addingTimeInterval(300)); j.intervals = [span]
        try Engine.answer(&j, intervalID: span.id, activityID: j.activities[0].id)
        let rest = j.activities[8].id, sleep = j.activities[6].id
        let session = try PersonalTracking.start(&j, activityID: rest, at: base.addingTimeInterval(3600))
        _ = try PersonalTracking.finish(&j, sessionID: session, at: base.addingTimeInterval(4500))
        try SleepTracking.start(&j, kind: .nap, at: base.addingTimeInterval(3 * 3600 + 15 * 60))
        try SleepTracking.wake(&j, at: base.addingTimeInterval(4 * 3600 + 15 * 60))
        XCTAssertEqual(j.entries.count, 3)
        XCTAssertEqual(j.entries.first { $0.activityID == rest }?.seconds, 900)
        XCTAssertEqual(j.entries.first { $0.activityID == sleep }?.seconds, 3600)
        XCTAssertEqual(j.sleepHistory?.restActivityID, sleep)
        let priority = Reports.dailyPriorityTotals(j, date: base)
        XCTAssertEqual(priority.currentSeconds, 3900)
        let cards = Reports.dashboardMetrics(j, range: Reports.allTimeRange(j), page: .summary)
        XCTAssertEqual(cards.map(\.seconds), [300, 0, 0])
        let complete = GoalReports.completionSummary(j, now: base.addingTimeInterval(5 * 3600))
        XCTAssertEqual(complete.daily.total, 4); XCTAssertEqual(complete.daily.completed, 2)
        try Engine.validate(j)
    }
    func testResetRestoresPresetWithoutReusingOldIDsOrHistory() throws {
        var j = Journal(); j.preferences.userName = "Tên riêng"; j.preferences.sound = false
        j.activities[0].name = "Đã sửa"; j.activities[0].isPriority = false
        try Engine.record(&j, entry: Entry(start: base, end: base.addingTimeInterval(300), activityID: j.activities[0].id))
        try GoalReports.saveDailyGoal(&j, activityID: j.activities[0].id, minutes: 60, at: base)
        let ids = Set(j.activities.map(\.id))
        j.reset(at: base); DashboardSelection.prepare(&j)
        XCTAssertEqual(j.activities.map(\.name), names)
        XCTAssertTrue(Set(j.activities.map(\.id)).isDisjoint(with: ids))
        XCTAssertNil(j.preferences.userName); XCTAssertTrue(j.preferences.sound)
        XCTAssertTrue(j.entries.isEmpty); XCTAssertTrue(j.goals.isEmpty)
        XCTAssertEqual(j.sleepReminders?.statisticsStartDay, "2025-11-07")
        for page in DashboardPage.allCases { XCTAssertEqual(DashboardSelection.selectedIDs(for: page, journal: j).count, 3) }
        try Engine.validate(j)
    }
    func testExistingJournalAndNewPresetRoundTripWithoutOverwritingStoredSettings() throws {
        var old = legacyJournal(); old.preferences.userName = "Tùy chỉnh"; old.activities[0].name = "Tên đang dùng"
        old.preferences.interfaceIcons = ["week": "star.fill"]
        try Engine.record(&old, entry: Entry(start: base, end: base.addingTimeInterval(300), activityID: old.activities[0].id))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repo = try Repository(url: folder.appendingPathComponent("journal.sqlite"))
        try repo.save(old); let reopened = try repo.load()
        XCTAssertEqual(reopened, old); XCTAssertFalse(reopened.preferences.sound)
        XCTAssertEqual(reopened.activities.count, 8); XCTAssertEqual(reopened.activities[0].name, "Tên đang dùng")
        XCTAssertEqual(InterfaceSection.week.symbol(in: reopened.preferences), "star.fill")
        var fresh = Journal(); DashboardSelection.prepare(&fresh)
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(fresh))
        XCTAssertEqual(decoded, fresh)
        var prepared = decoded; PersonalTracking.prepare(&prepared); XCTAssertEqual(prepared, decoded)
        try repo.save(fresh); XCTAssertEqual(try repo.load(), fresh)
    }
}

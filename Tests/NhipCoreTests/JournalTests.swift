import Foundation
import NhipCore

final class JournalTests {
    let base = Date(timeIntervalSince1970: 1_735_689_600)
    func at(_ minute: Double) -> Date { base.addingTimeInterval(minute * 60) }
    func fullRange(_ minutes: Double = 60) -> DateInterval { DateInterval(start: base, end: at(minutes)) }

    func testThreeFiveMinuteIntervals() {
        var j = legacyJournal(); Engine.start(&j, at: base)
        let completed = Engine.tick(&j, at: at(15))
        XCTAssertEqual(completed.count, 3)
        XCTAssertEqual(j.intervals.map(\.seconds), [300,300,300])
        XCTAssertEqual(j.intervals[1].start, at(5)); XCTAssertEqual(j.runtime.nextDue, at(20))
    }
    func testAdjacentAnswersTotalWithoutDoubleCounting() throws {
        var j = legacyJournal(); Engine.start(&j, at: base); Engine.tick(&j, at: at(10))
        for span in j.intervals { try Engine.answer(&j, intervalID: span.id, activityID: j.activities[0].id) }
        let report = Reports.summarize(j, range: fullRange())
        XCTAssertEqual(report.total, 600); XCTAssertEqual(report.unknown, 0); XCTAssertEqual(report.coverage, 1)
    }
    func testUnknownDoesNotContinueLastActivity() throws {
        var j = legacyJournal(); Engine.start(&j, at: base); Engine.tick(&j, at: at(10))
        try Engine.answer(&j, intervalID: j.intervals[0].id, activityID: j.activities[0].id)
        let r = Reports.summarize(j, range: fullRange())
        XCTAssertEqual(r.total, 300); XCTAssertEqual(r.unknown, 300); XCTAssertEqual(r.coverage, 0.5)
    }
    func testRepeatedNotificationIsIdempotent() throws {
        var j = legacyJournal(); Engine.start(&j, at: base); Engine.tick(&j, at: at(5))
        let id = j.intervals[0].id
        try Engine.answer(&j, intervalID: id, activityID: j.activities[0].id)
        try Engine.answer(&j, intervalID: id, activityID: j.activities[1].id)
        XCTAssertEqual(j.entries.count, 1); XCTAssertEqual(j.entries[0].activityID, j.activities[0].id)
    }
    func testDelayedAnswerKeepsOriginalTime() throws {
        var j = legacyJournal(); Engine.start(&j, at: base); Engine.tick(&j, at: at(20))
        try Engine.answer(&j, intervalID: j.intervals[0].id, activityID: j.activities[0].id)
        XCTAssertEqual(j.entries[0].start, base); XCTAssertEqual(j.entries[0].end, at(5))
        XCTAssertEqual(Reports.summarize(j, range: fullRange()).unknown, 900)
    }
    func testPauseClosesPartialAndDoesNotCountOffline() {
        var j = legacyJournal(); Engine.start(&j, at: base)
        Engine.pause(&j, at: at(7), minutes: nil)
        Engine.tick(&j, at: at(60))
        XCTAssertEqual(j.intervals.reduce(0) { $0 + $1.seconds }, 420)
        XCTAssertNil(j.runtime.nextDue); XCTAssertFalse(j.runtime.enabled)
    }
    func testTimedPauseStartsNewCycleAtReturn() {
        var j = legacyJournal(); Engine.start(&j, at: base); Engine.pause(&j, at: at(2), minutes: 15)
        Engine.tick(&j, at: at(16)); XCTAssertNil(j.runtime.nextDue)
        Engine.tick(&j, at: at(17)); XCTAssertEqual(j.runtime.nextDue, at(22))
    }
    func testRecoverOnlyUntilHeartbeat() {
        var j = legacyJournal(); Engine.start(&j, at: base); Engine.tick(&j, at: at(7))
        Engine.recover(&j)
        XCTAssertEqual(j.intervals.reduce(0) { $0 + $1.seconds }, 420)
        XCTAssertNil(j.runtime.segmentStart)
        Engine.tick(&j, at: at(100)); XCTAssertEqual(j.runtime.segmentStart, at(100))
        XCTAssertEqual(j.intervals.reduce(0) { $0 + $1.seconds }, 420)
    }
    func testEditChangesOnlyClassification() throws {
        var j = legacyJournal(); let first = Entry(start: base, end: at(10), activityID: j.activities[0].id)
        try Engine.record(&j, entry: first)
        var edited = first; edited.activityID = j.activities[1].id
        try Engine.record(&j, entry: edited)
        let report = Reports.summarize(j, range: fullRange())
        XCTAssertNil(report.totals[j.activities[0].id]); XCTAssertEqual(report.totals[j.activities[1].id], 600)
    }
    func testOutsideManualEntryDoesNotChangeCoverage() throws {
        var j = legacyJournal(); j.intervals = [Span(start: base, end: at(15))]
        try Engine.record(&j, entry: Entry(start: base, end: at(10), activityID: j.activities[0].id))
        try Engine.record(&j, entry: Entry(start: at(30), end: at(60), activityID: j.activities[2].id))
        let r = Reports.summarize(j, range: fullRange())
        XCTAssertEqual(r.total, 2400); XCTAssertEqual(r.manualOutside, 1800)
        XCTAssertEqual(r.coverage!, 2.0 / 3, accuracy: 0.00001)
    }
    func testOverlapRejectedWithoutMutation() throws {
        var j = legacyJournal(); try Engine.record(&j, entry: Entry(start: base, end: at(20), activityID: j.activities[0].id))
        let original = j
        XCTAssertThrowsError(try Engine.record(&j, entry: Entry(start: at(5), end: at(10), activityID: j.activities[1].id)))
        XCTAssertEqual(j, original)
    }
    func testReplacingPreservesBothSides() throws {
        var j = legacyJournal(); try Engine.record(&j, entry: Entry(start: base, end: at(20), activityID: j.activities[0].id))
        try Engine.record(&j, entry: Entry(start: at(5), end: at(10), activityID: j.activities[1].id), replacing: true)
        XCTAssertEqual(j.entries.count, 3); try Engine.validate(j)
        let r = Reports.summarize(j, range: fullRange())
        XCTAssertEqual(r.total, 1200); XCTAssertEqual(r.totals[j.activities[0].id], 900)
    }
    func testAnswerOnlyFillsRemainingGaps() throws {
        var j = legacyJournal(); let span = Span(start: base, end: at(10)); j.intervals = [span]
        try Engine.record(&j, entry: Entry(start: at(3), end: at(7), activityID: j.activities[0].id))
        try Engine.answer(&j, intervalID: span.id, activityID: j.activities[1].id)
        XCTAssertEqual(j.entries.count, 3)
        XCTAssertEqual(Reports.summarize(j, range: fullRange()).totals[j.activities[1].id], 360)
    }
    func testCrossMidnightClipping() throws {
        var j = legacyJournal(); let c = j.preferences.calendar
        let midnight = c.startOfDay(for: base)
        let start = midnight.addingTimeInterval(-300), end = midnight.addingTimeInterval(300)
        try Engine.record(&j, entry: Entry(start: start, end: end, activityID: j.activities[0].id))
        XCTAssertEqual(Reports.summarize(j, range: DateInterval(start: midnight.addingTimeInterval(-86400), end: midnight)).total, 300)
        XCTAssertEqual(Reports.summarize(j, range: DateInterval(start: midnight, end: midnight.addingTimeInterval(86400))).total, 300)
    }
    func testEmptyReportHasNoCoverage() { XCTAssertNil(Reports.summarize(legacyJournal(), range: fullRange()).coverage) }
    func testArchiveAndRenameKeepTotals() throws {
        var j = legacyJournal(); try Engine.record(&j, entry: Entry(start: base, end: at(5), activityID: j.activities[0].id))
        j.activities[0].name = "Tên mới"; j.activities[0].archived = true
        XCTAssertEqual(Reports.summarize(j, range: fullRange()).total, 300); try Engine.validate(j)
    }
    func testBackupRoundTripAndRepository() throws {
        var j = legacyJournal(); try Engine.record(&j, entry: Entry(start: base, end: at(5), activityID: j.activities[0].id, note: "Tiếng Việt, dấu \"ngoặc\""))
        j.goals = [Goal(activityID: j.activities[0].id, direction: "increase", minutes: 180, effectiveFrom: base)]
        let decoded = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j)); XCTAssertEqual(j, decoded)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = try Repository(url: directory.appendingPathComponent("test.sqlite")); try repo.save(j)
        XCTAssertEqual(try repo.load(), j)
    }
    func testInvalidBackupRejected() {
        var j = legacyJournal(); j.schemaVersion = 99; XCTAssertThrowsError(try Engine.validate(j))
        j.schemaVersion = 1; j.preferences.timezone = "invalid"; XCTAssertThrowsError(try Engine.validate(j))
    }
    func testBackupOverlappingIntervalsRejected() {
        var j = legacyJournal(); j.intervals = [Span(start: base, end: at(10)), Span(start: at(5), end: at(15))]
        XCTAssertThrowsError(try Engine.validate(j))
    }
    func testCSVClipsEscapesAndNeutralizesFormula() throws {
        var j = legacyJournal(); try Engine.record(&j, entry: Entry(start: base, end: at(20), activityID: j.activities[0].id, note: "=1+1,\"x\""))
        let csv = Reports.csv(j, range: DateInterval(start: at(5), end: at(10)))
        XCTAssertTrue(csv.contains("5.0000")); XCTAssertTrue(csv.contains("'=1+1,\"\"x\"\""))
    }
    func testScheduledBoundaryAndOfflineGap() {
        var j = legacyJournal(); let c = j.preferences.calendar
        let day = c.startOfDay(for: base), weekday = c.component(.weekday, from: day)
        j.preferences.scheduled = true; j.preferences.windows = [ScheduleWindow(weekday: weekday, startMinute: 8 * 60, endMinute: 8 * 60 + 7)]
        let start = c.date(byAdding: .minute, value: 8 * 60, to: day)!
        Engine.start(&j, at: start); Engine.tick(&j, at: start.addingTimeInterval(15 * 60))
        XCTAssertEqual(j.intervals.reduce(0) { $0 + $1.seconds }, 420)
        XCTAssertNil(j.runtime.nextDue)
    }
    func testCurrentMonthComparisonUsesSharedDays() {
        let c = legacyJournal().preferences.calendar
        let now = c.date(from: DateComponents(year: 2025, month: 3, day: 31, hour: 12))!
        let ranges = Reports.comparisonRanges(period: .month, date: now, now: now, calendar: c)
        XCTAssertEqual(c.component(.day, from: ranges.0.end), 28)
        XCTAssertEqual(c.component(.day, from: ranges.1.end), 28)
        XCTAssertEqual(c.component(.hour, from: ranges.1.end), 12)
    }
    func testDSTDayUsesActualDuration() {
        var j = legacyJournal(); j.preferences.timezone = "America/New_York"
        let c = j.preferences.calendar, day = c.date(from: DateComponents(year: 2025, month: 3, day: 9))!
        let range = Reports.range(.day, date: day, calendar: c)
        XCTAssertEqual(range.duration, 23 * 3600)
    }
    func testPendingSweepHandlesGapsAndLongEntries() throws {
        var j = legacyJournal(); j.intervals = (0..<4).map { Span(start: at(Double($0 * 5)), end: at(Double(($0+1) * 5))) }
        try Engine.record(&j, entry: Entry(start: base, end: at(7), activityID: j.activities[0].id))
        try Engine.record(&j, entry: Entry(start: at(8), end: at(20), activityID: j.activities[0].id))
        XCTAssertEqual(Engine.pendingIntervals(j).map(\.id), [j.intervals[1].id])
    }
    func testCheckpointAndExclusiveProcessLock() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        let repo = try Repository(url: url); var j = legacyJournal(); try repo.save(j)
        XCTAssertThrowsError(try Repository(url: url))
        Engine.start(&j, at: base); try repo.saveRuntime(j.runtime)
        XCTAssertEqual(try repo.load().runtime, j.runtime)
        j.runtime.enabled = false; try repo.save(j)
        XCTAssertEqual(try repo.load().runtime, j.runtime)
    }
    func testStartingTwiceDoesNotDiscardTime() {
        var j = legacyJournal(); Engine.start(&j, at: base); Engine.start(&j, at: at(2))
        Engine.tick(&j, at: at(5)); XCTAssertEqual(j.intervals.first?.seconds, 300)
    }
    func testRecentCheckInNeverFallsBackToMissedOrSkippedIntervals() throws {
        var j = legacyJournal()
        let older = Span(start: base, end: at(2)), latest = Span(start: at(2), end: at(4))
        j.intervals = [latest, older] // Backup ordering must not determine the latest interval.
        XCTAssertEqual(Engine.recentCheckIn(j, at: at(5))?.id, latest.id)
        j.skipped = [latest.id]
        XCTAssertNil(Engine.recentCheckIn(j, at: at(5)))
        j.skipped = []
        try Engine.answer(&j, intervalID: latest.id, activityID: j.activities[0].id)
        XCTAssertNil(Engine.recentCheckIn(j, at: at(5)))
        XCTAssertEqual(Reports.summarize(j, range: fullRange()).total, 120)
    }
    func testRecentCheckInExpiresWithoutResurfacingBacklog() {
        var j = legacyJournal(); let span = Span(start: base, end: at(5)); j.intervals = [span]
        XCTAssertNil(Engine.recentCheckIn(j, at: at(4)))
        XCTAssertEqual(Engine.recentCheckIn(j, at: at(5))?.id, span.id)
        XCTAssertEqual(Engine.recentCheckIn(j, at: at(9.99))?.id, span.id)
        XCTAssertNil(Engine.recentCheckIn(j, at: at(10)))
        XCTAssertNil(Engine.recentCheckIn(j, at: at(100)))
    }
    func testAllTimeTotalsIncludeOlderYearsAndArchivedActivities() throws {
        var j = legacyJournal()
        let oldStart = base.addingTimeInterval(-400 * 86400)
        try Engine.record(&j, entry: Entry(start: oldStart, end: oldStart.addingTimeInterval(3600), activityID: j.activities[0].id))
        try Engine.record(&j, entry: Entry(start: base, end: at(30), activityID: j.activities[1].id))
        j.activities[1].archived = true
        j.entries.reverse()
        j.intervals = [Span(start: oldStart.addingTimeInterval(-86400), end: at(600))]
        let range = Reports.allTimeRange(j, now: at(1000))
        XCTAssertEqual(range.start, oldStart); XCTAssertEqual(range.end, at(30))
        let report = Reports.summarize(j, range: range)
        XCTAssertEqual(report.total, 5400)
        XCTAssertEqual(report.totals[j.activities[0].id], 3600)
        XCTAssertEqual(report.totals[j.activities[1].id], 1800)
    }
    func testAllTimeReportHandlesEmptyHistory() {
        let j = legacyJournal(), range = Reports.allTimeRange(legacyJournal(), now: base)
        XCTAssertEqual(range.start, base); XCTAssertEqual(range.duration, 0)
        XCTAssertEqual(Reports.summarize(j, range: range).total, 0)
    }
    func testDaysWithDataAreClippedAndNotDoubleCounted() {
        var j = legacyJournal(); let c = j.preferences.calendar
        let midnight = c.startOfDay(for: base)
        j.intervals = [Span(start: midnight.addingTimeInterval(-300), end: midnight.addingTimeInterval(300)), Span(start: midnight.addingTimeInterval(600), end: midnight.addingTimeInterval(900))]
        j.entries = [Entry(start: midnight.addingTimeInterval(-300), end: midnight.addingTimeInterval(300), activityID: j.activities[0].id)]
        XCTAssertEqual(Reports.daysWithData(j, range: DateInterval(start: midnight, end: midnight.addingTimeInterval(86400))), 1)
        XCTAssertEqual(Reports.daysWithData(j, range: DateInterval(start: midnight.addingTimeInterval(-86400), end: midnight.addingTimeInterval(86400))), 2)
    }
}

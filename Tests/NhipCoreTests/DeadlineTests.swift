import Foundation
import NhipCore

final class DeadlineTests {
    let base = ISO8601DateFormatter().date(from: "2025-11-03T00:00:00+07:00")!
    func day(_ offset: Double) -> Date { base.addingTimeInterval(offset * 86400) }
    func journal() -> Journal { var j = legacyJournal(); SleepPlan.setEnabled(false, journal: &j); return j }
    func add(_ j: inout Journal, activity: Int = 0, start: Date, hours: Double, source: String = "manual") throws {
        try Engine.record(&j, entry: Entry(start: start, end: start.addingTimeInterval(hours * 3600), activityID: j.activities[activity].id, source: source))
    }
    func create(_ j: inout Journal, hours: Int = 20, due: Double = 10) throws -> DeadlinePlan {
        let id = try Deadlines.create(&j, title: "My deadline", dueAt: day(due), targets: [DeadlineTarget(activityID: j.activities[0].id, minutes: hours * 60)], now: base)
        return j.deadlines!.first { $0.id == id }!
    }
    func testLifecycleAndInvalidInputAreAtomic() throws {
        var j = journal(); let original = j
        XCTAssertThrowsError(try Deadlines.create(&j, title: "", dueAt: day(10), targets: [DeadlineTarget(activityID: j.activities[0].id, minutes: 60)], now: base))
        XCTAssertThrowsError(try Deadlines.create(&j, title: "Name", dueAt: base, targets: [], now: base))
        XCTAssertThrowsError(try Deadlines.create(&j, title: "Name", dueAt: day(-1), targets: [], now: base))
        XCTAssertThrowsError(try Deadlines.create(&j, title: "Name", dueAt: day(10), targets: [DeadlineTarget(activityID: UUID(), minutes: 60)], now: base))
        XCTAssertThrowsError(try Deadlines.create(&j, title: "Name", dueAt: day(10), targets: [DeadlineTarget(activityID: j.activities[0].id, minutes: 0)], now: base))
        XCTAssertEqual(j, original)
        let id = try Deadlines.create(&j, title: "  My   deadline \n", dueAt: day(10), targets: [DeadlineTarget(activityID: j.activities[0].id, minutes: 60)], now: base)
        XCTAssertEqual(j.deadlines?.first?.title, "My deadline")
        XCTAssertEqual(j.deadlines?.first?.createdAt, base)
        Deadlines.delete(&j, id: id); XCTAssertEqual(j, original)
    }
    func testKnownDailyPaceProjectsTotalAtDeadline() throws {
        var j = journal(); let plan = try create(&j)
        try add(&j, start: day(0), hours: 2)
        try add(&j, start: day(1), hours: 2)
        let report = Deadlines.forecast(plan, journal: j, now: day(2)), row = report.activities[0]
        XCTAssertEqual(row.recordedSeconds, 4 * 3600)
        XCTAssertEqual(row.averageSecondsPerDay!, 2 * 3600, accuracy: 0.001)
        XCTAssertEqual(row.projectedSeconds!, 20 * 3600, accuracy: 0.001)
        XCTAssertEqual(row.requiredSecondsPerDay!, 2 * 3600, accuracy: 0.001)
        XCTAssertFalse(row.isAtRisk); XCTAssertFalse(row.isComplete)
        XCTAssertEqual(report.atRiskCount, 0); XCTAssertFalse(report.isEarlyEstimate)
    }
    func testMissingDaysLowerPaceAndRaiseShortfall() throws {
        var j = journal(); let plan = try create(&j)
        try add(&j, start: day(0), hours: 2)
        let report = Deadlines.forecast(plan, journal: j, now: day(2)), row = report.activities[0]
        XCTAssertEqual(row.averageSecondsPerDay!, 3600, accuracy: 0.001)
        XCTAssertEqual(row.projectedSeconds!, 10 * 3600, accuracy: 0.001)
        XCTAssertEqual(row.projectedShortfall!, 10 * 3600, accuracy: 0.001)
        XCTAssertEqual(row.requiredSecondsPerDay!, 2.25 * 3600, accuracy: 0.001)
        XCTAssertTrue(row.isAtRisk); XCTAssertEqual(report.atRiskCount, 1)
    }
    func testEachActivityWarnsEvenWhenTotalHoursLookEnough() throws {
        var j = journal()
        try Deadlines.create(&j, title: "Two activities", dueAt: day(10), targets: [DeadlineTarget(activityID: j.activities[0].id, minutes: 10 * 60), DeadlineTarget(activityID: j.activities[1].id, minutes: 5 * 60)], now: base)
        try add(&j, start: day(0), hours: 10)
        try add(&j, start: day(1), hours: 10)
        let report = Deadlines.forecast(j.deadlines![0], journal: j, now: day(2))
        XCTAssertTrue(report.projectedSeconds! > report.targetSeconds)
        XCTAssertFalse(report.activities[0].isAtRisk); XCTAssertTrue(report.activities[1].isAtRisk)
        XCTAssertEqual(report.atRiskCount, 1); XCTAssertFalse(report.isComplete)
    }
    func testTimeIsClippedAtCreationAndDeadline() throws {
        var j = journal(); let plan = try create(&j, hours: 1, due: 2)
        try add(&j, start: base.addingTimeInterval(-3600), hours: 2)
        try add(&j, start: day(2).addingTimeInterval(-1800), hours: 1)
        let report = Deadlines.forecast(plan, journal: j, now: day(3))
        XCTAssertEqual(report.recordedSeconds, 1.5 * 3600)
        XCTAssertEqual(report.projectedSeconds!, 1.5 * 3600)
        XCTAssertTrue(report.isExpired); XCTAssertTrue(report.isComplete)
        XCTAssertEqual(report.remainingSeconds, 0)
        XCTAssertNil(report.activities[0].requiredSecondsPerDay)
    }
    func testOldAndNotYetObservedEntriesAreExcluded() throws {
        var j = journal(); let plan = try create(&j)
        try add(&j, start: day(-20), hours: 8)
        try add(&j, start: day(1), hours: 2)
        try add(&j, start: day(3), hours: 8)
        try add(&j, activity: 1, start: day(1).addingTimeInterval(3 * 3600), hours: 1)
        let report = Deadlines.forecast(plan, journal: j, now: day(2))
        XCTAssertEqual(report.recordedSeconds, 2 * 3600)
        XCTAssertEqual(report.projectedSeconds!, 10 * 3600, accuracy: 0.001)
    }
    func testFirstQuarterHourAndInitialEstimateNeverDivideByZero() throws {
        var j = journal(); let plan = try create(&j)
        let first = Deadlines.forecast(plan, journal: j, now: base)
        XCTAssertNil(first.projectedSeconds); XCTAssertNil(first.activities[0].averageSecondsPerDay)
        XCTAssertEqual(first.recordedSeconds, 0); XCTAssertEqual(first.atRiskCount, 0)
        XCTAssertNil(Deadlines.forecast(plan, journal: j, now: base.addingTimeInterval(899)).projectedSeconds)
        let minute = Deadlines.forecast(plan, journal: j, now: base.addingTimeInterval(900))
        XCTAssertEqual(minute.projectedSeconds!, 0); XCTAssertTrue(minute.isEarlyEstimate)
        XCTAssertEqual(minute.atRiskCount, 1)
        XCTAssertFalse(Deadlines.forecast(plan, journal: j, now: day(1)).isEarlyEstimate)
        let before = Deadlines.forecast(plan, journal: j, now: day(-1))
        XCTAssertEqual(before.observedSeconds, 0); XCTAssertEqual(before.remainingSeconds, 10 * 86400)
    }
    func testEveryTargetMustActuallyComplete() throws {
        var j = journal()
        try Deadlines.create(&j, title: "Both", dueAt: day(2), targets: [DeadlineTarget(activityID: j.activities[0].id, minutes: 60), DeadlineTarget(activityID: j.activities[1].id, minutes: 60)], now: base)
        try add(&j, start: base, hours: 2)
        XCTAssertFalse(Deadlines.forecast(j.deadlines![0], journal: j, now: day(1)).isComplete)
        try add(&j, activity: 1, start: day(1), hours: 1)
        let report = Deadlines.forecast(j.deadlines![0], journal: j, now: day(2))
        XCTAssertTrue(report.isComplete); XCTAssertTrue(report.isExpired)
        XCTAssertEqual(report.atRiskCount, 0)
        XCTAssertEqual(report.activities[0].fraction, 1)
    }
    func testExpiredForecastIsActualResultNotAnExtrapolation() throws {
        var j = journal(); let plan = try create(&j, hours: 20, due: 2)
        try add(&j, start: base, hours: 2)
        let atDue = Deadlines.forecast(plan, journal: j, now: day(2))
        let later = Deadlines.forecast(plan, journal: j, now: day(10))
        XCTAssertEqual(atDue.projectedSeconds!, 2 * 3600)
        XCTAssertEqual(atDue.projectedSeconds, later.projectedSeconds)
        XCTAssertEqual(later.activities[0].projectedShortfall!, 18 * 3600)
        XCTAssertFalse(later.isComplete); XCTAssertEqual(later.atRiskCount, 1)
    }
    func testRecordingModesRenameAndArchiveKeepStableTotals() throws {
        var j = journal()
        try Deadlines.create(&j, title: "All modes", dueAt: day(10), targets: [0, 1, 6].map { DeadlineTarget(activityID: j.activities[$0].id, minutes: 120) }, now: base)
        try add(&j, start: base, hours: 1, source: "checkin")
        try add(&j, activity: 1, start: base.addingTimeInterval(3600), hours: 1, source: "personal-timer")
        try add(&j, activity: 6, start: base.addingTimeInterval(7200), hours: 2, source: "sleep")
        let first = Deadlines.forecast(j.deadlines![0], journal: j, now: day(2))
        j.activities[0].name = "Renamed"; j.activities[0].symbol = "star.fill"; j.activities[0].archived = true
        let changed = Deadlines.forecast(j.deadlines![0], journal: j, now: day(2))
        XCTAssertEqual(first.recordedSeconds, 4 * 3600); XCTAssertEqual(first.recordedSeconds, changed.recordedSeconds)
        XCTAssertEqual(first.projectedSeconds, changed.projectedSeconds)
        XCTAssertEqual(Reports.summarize(j, range: Reports.allTimeRange(j)).total, 4 * 3600)
    }
    func testEditingPreservesCreationAndUsesFullObservedHistory() throws {
        var j = journal(); let plan = try create(&j)
        try add(&j, start: base, hours: 2)
        try Deadlines.update(&j, id: plan.id, title: "Changed", dueAt: day(20), targets: [DeadlineTarget(activityID: j.activities[0].id, minutes: 40 * 60)], now: day(2))
        let edited = j.deadlines![0]
        XCTAssertEqual(edited.createdAt, base); XCTAssertEqual(edited.title, "Changed")
        XCTAssertEqual(Deadlines.forecast(edited, journal: j, now: day(2)).projectedSeconds!, 20 * 3600, accuracy: 0.001)
        let before = j
        XCTAssertThrowsError(try Deadlines.update(&j, id: plan.id, title: "Late", dueAt: day(30), targets: edited.targets, now: day(21)))
        XCTAssertEqual(j, before)
    }
    func testDeletionNeverChangesEntriesGoalsOrCompletionTotals() throws {
        var j = journal(); let plan = try create(&j)
        try GoalReports.saveDailyPlan(&j, activityID: j.activities[0].id, minutes: 60, on: base)
        try add(&j, start: base, hours: 2)
        let before = j, summary = GoalReports.completionSummary(j, now: day(2))
        Deadlines.delete(&j, id: plan.id)
        XCTAssertEqual(j.entries, before.entries); XCTAssertEqual(j.goals, before.goals)
        XCTAssertEqual(GoalReports.completionSummary(j, now: day(2)).daily.completed, summary.daily.completed)
        try HistoryProtection.validateChange(from: before, to: j, now: day(2))
    }
    func testSQLiteJSONAndLegacyDataRoundTrip() throws {
        var j = journal()
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(j)) as! [String: Any]
        XCTAssertNil(object["deadlines"])
        XCTAssertEqual(try JSONDecoder().decode(Journal.self, from: JSONSerialization.data(withJSONObject: object)), j)
        _ = try create(&j)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try Repository(url: directory.appendingPathComponent("deadlines.sqlite"))
        try repository.save(j); XCTAssertEqual(try repository.load(), j)
        XCTAssertEqual(try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(j)), j)
    }
    func testResetClearsDeadlinesAndDoesNotCarryPersonalPlansIntoDefaults() throws {
        var j = journal(); _ = try create(&j)
        j.reset(at: day(2))
        XCTAssertNil(j.deadlines); XCTAssertNil(Journal().deadlines)
        XCTAssertTrue(j.entries.isEmpty); XCTAssertTrue(j.goals.isEmpty)
    }
    func testInvalidStoredDeadlineDataIsRejected() throws {
        var j = journal(); let plan = try create(&j)
        var bad = j; bad.deadlines!.append(plan); XCTAssertThrowsError(try Engine.validate(bad))
        bad = j; bad.deadlines![0].targets.append(plan.targets[0]); XCTAssertThrowsError(try Engine.validate(bad))
        bad = j; bad.deadlines![0].dueAt = base; XCTAssertThrowsError(try Engine.validate(bad))
        bad = j; bad.deadlines![0].targets[0].minutes = -1; XCTAssertThrowsError(try Engine.validate(bad))
        bad = j; bad.deadlines![0].targets[0].activityID = UUID(); XCTAssertThrowsError(try Engine.validate(bad))
        bad = j; bad.deadlines![0].createdAt = Date(timeIntervalSince1970: .infinity); XCTAssertThrowsError(try Engine.validate(bad))
        try Engine.validate(j)
    }
    func testHistoryGuardProtectsCreationAndExpiredPlans() throws {
        var j = journal(); _ = try create(&j)
        var changed = j; changed.deadlines![0].createdAt = day(1)
        XCTAssertThrowsError(try HistoryProtection.validateChange(from: j, to: changed, now: day(2)))
        changed = j; changed.deadlines![0].title = "Changed"
        try HistoryProtection.validateChange(from: j, to: changed, now: day(2))
        XCTAssertThrowsError(try HistoryProtection.validateChange(from: j, to: changed, now: day(10)))
        try HistoryProtection.validateChange(from: j, to: j, now: day(10))
    }
    func testDSTUsesActualElapsedTimeForDailyAverage() throws {
        var j = journal(); j.preferences.timezone = "America/New_York"
        let f = ISO8601DateFormatter(), start = f.date(from: "2025-11-02T00:00:00-04:00")!
        let now = f.date(from: "2025-11-03T00:00:00-05:00")!, due = f.date(from: "2025-11-04T00:00:00-05:00")!
        try Deadlines.create(&j, title: "DST", dueAt: due, targets: [DeadlineTarget(activityID: j.activities[0].id, minutes: 10 * 60)], now: start)
        try add(&j, start: start, hours: 5)
        let report = Deadlines.forecast(j.deadlines![0], journal: j, now: now)
        XCTAssertEqual(report.observedSeconds, 25 * 3600)
        XCTAssertEqual(report.activities[0].averageSecondsPerDay!, 4.8 * 3600, accuracy: 0.001)
        XCTAssertEqual(report.projectedSeconds!, 9.8 * 3600, accuracy: 0.001)
    }
    func testSamplesFollowCreationTimeAndExactQuarterHourBoundaries() throws {
        var j = journal(); let start = base.addingTimeInterval(7 * 60)
        try Deadlines.create(&j, title: "Offset", dueAt: day(10), targets: [DeadlineTarget(activityID: j.activities[0].id, minutes: 1200)], now: start)
        let plan = j.deadlines![0]
        try add(&j, start: start, hours: 5.0 / 60)
        XCTAssertNil(Deadlines.forecast(plan, journal: j, now: start.addingTimeInterval(899)).sample)
        let first = Deadlines.forecast(plan, journal: j, now: start.addingTimeInterval(900))
        XCTAssertEqual(first.sample?.sampledAt, start.addingTimeInterval(900))
        XCTAssertEqual(first.nextSampleAt, start.addingTimeInterval(1800))
        let before = Deadlines.forecast(plan, journal: j, now: start.addingTimeInterval(1799), previousSample: first.sample)
        XCTAssertEqual(before.sample, first.sample)
        XCTAssertEqual(before.activities[0].averageSecondsPerDay, first.activities[0].averageSecondsPerDay)
        let next = Deadlines.forecast(plan, journal: j, now: start.addingTimeInterval(1800), previousSample: first.sample)
        XCTAssertEqual(next.sample?.sampledAt, start.addingTimeInterval(1800))
        XCTAssertEqual(next.activities[0].averageSecondsPerDay!, first.activities[0].averageSecondsPerDay! / 2, accuracy: 0.001)
        let afterOffline = Deadlines.forecast(plan, journal: j, now: start.addingTimeInterval(2 * 3600 + 7 * 60), previousSample: next.sample)
        XCTAssertEqual(afterOffline.sample?.sampledAt, start.addingTimeInterval(2 * 3600))
        XCTAssertEqual(afterOffline.nextSampleAt, start.addingTimeInterval(2 * 3600 + 900))
    }
    func testLateAnswersWaitForNextSampleWhileProgressUpdates() throws {
        var j = journal(); let plan = try create(&j)
        let first = Deadlines.forecast(plan, journal: j, now: base.addingTimeInterval(900))
        XCTAssertEqual(first.activities[0].averageSecondsPerDay!, 0)
        try add(&j, start: base, hours: 5.0 / 60, source: "checkin")
        let live = Deadlines.forecast(plan, journal: j, now: base.addingTimeInterval(1000), previousSample: first.sample)
        XCTAssertEqual(live.recordedSeconds, 300)
        XCTAssertEqual(live.activities[0].averageSecondsPerDay!, 0)
        XCTAssertEqual(live.projectedSeconds, first.projectedSeconds)
        let next = Deadlines.forecast(plan, journal: j, now: base.addingTimeInterval(1800), previousSample: live.sample)
        XCTAssertEqual(next.activities[0].averageSecondsPerDay!, 4 * 3600, accuracy: 0.001)
        XCTAssertTrue(next.projectedSeconds! > 0)
    }
    func testForecastAndRequiredDailyHoursStayFixedBetweenSamples() throws {
        var j = journal(); let plan = try create(&j)
        try add(&j, start: base, hours: 10.0 / 60)
        let first = Deadlines.forecast(plan, journal: j, now: base.addingTimeInterval(900))
        try add(&j, start: base.addingTimeInterval(900), hours: 3.0 / 60)
        let live = Deadlines.forecast(plan, journal: j, now: base.addingTimeInterval(1200), previousSample: first.sample)
        XCTAssertEqual(live.recordedSeconds, 13 * 60)
        XCTAssertEqual(live.projectedSeconds, first.projectedSeconds)
        XCTAssertEqual(live.activities[0].requiredSecondsPerDay, first.activities[0].requiredSecondsPerDay)
        XCTAssertTrue(live.remainingSeconds < first.remainingSeconds)
        XCTAssertEqual(live.sample, first.sample)
    }
    func testDeadlineBeforeFirstSampleStillReportsExactFinalResult() throws {
        var j = journal()
        try Deadlines.create(&j, title: "Short", dueAt: base.addingTimeInterval(12 * 60), targets: [DeadlineTarget(activityID: j.activities[0].id, minutes: 10)], now: base)
        let plan = j.deadlines![0]
        try add(&j, start: base, hours: 10.0 / 60)
        let before = Deadlines.forecast(plan, journal: j, now: base.addingTimeInterval(11 * 60))
        XCTAssertNil(before.projectedSeconds)
        XCTAssertEqual(before.nextSampleAt, plan.dueAt)
        let final = Deadlines.forecast(plan, journal: j, now: plan.dueAt)
        XCTAssertTrue(final.isExpired); XCTAssertTrue(final.isComplete)
        XCTAssertEqual(final.projectedSeconds!, 10 * 60)
        XCTAssertNil(final.activities[0].averageSecondsPerDay)
        XCTAssertEqual(final.sample?.sampledAt, plan.dueAt)
        XCTAssertNil(final.nextSampleAt)
        try add(&j, start: base.addingTimeInterval(10 * 60), hours: 1.0 / 60)
        let corrected = Deadlines.forecast(plan, journal: j, now: plan.dueAt.addingTimeInterval(60), previousSample: final.sample)
        XCTAssertEqual(corrected.projectedSeconds!, 11 * 60)
        XCTAssertEqual(corrected.sample?.seconds[plan.targets[0].activityID], 11 * 60)
    }
    func testPlanChangesInvalidateSampleWithoutResettingItsClock() throws {
        var j = journal(); let plan = try create(&j)
        let first = Deadlines.forecast(plan, journal: j, now: base.addingTimeInterval(900))
        try add(&j, start: base, hours: 5.0 / 60)
        try Deadlines.update(&j, id: plan.id, title: "Updated", dueAt: day(20), targets: plan.targets, now: base.addingTimeInterval(1000))
        let updated = j.deadlines![0]
        let report = Deadlines.forecast(updated, journal: j, now: base.addingTimeInterval(1000), previousSample: first.sample)
        XCTAssertEqual(report.sample?.sampledAt, base.addingTimeInterval(900))
        XCTAssertEqual(report.nextSampleAt, base.addingTimeInterval(1800))
        XCTAssertTrue(report.activities[0].averageSecondsPerDay! > 0)
        XCTAssertEqual(updated.createdAt, plan.createdAt)
    }

}

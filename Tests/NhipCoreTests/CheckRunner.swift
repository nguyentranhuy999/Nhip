import Foundation
import NhipCore

private var failures: [String] = []
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #file, line: UInt = #line) {
    if a != b { failures.append("\(file):\(line): \(a) != \(b)") }
}
func XCTAssertEqual(_ a: Double, _ b: Double, accuracy: Double, file: StaticString = #file, line: UInt = #line) {
    if abs(a - b) > accuracy { failures.append("\(file):\(line): \(a) != \(b) ± \(accuracy)") }
}
func XCTAssertTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) { if !value { failures.append("\(file):\(line): expected true") } }
func XCTAssertFalse(_ value: Bool, file: StaticString = #file, line: UInt = #line) { XCTAssertTrue(!value, file: file, line: line) }
func XCTAssertNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) { XCTAssertTrue(value == nil, file: file, line: line) }
func XCTAssertThrowsError<T>(_ operation: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) {
    do { _ = try operation(); failures.append("\(file):\(line): expected an error") } catch {}
}

@main struct CheckRunner {
    static func main() {
        let t = JournalTests()
        let g = GoalTests()
        let p = PeriodNavigationTests()
        let w = WeeklyGoalTests()
        let s = SleepTests()
        let r = ReminderLifetimeTests()
        let sleep = SleepTrackingTests()
        let personal = PersonalTrackingTests()
        let modes = RecordingModeTests()
        let priority = PriorityTests()
        let appearance = ActivityAppearanceTests()
        let completion = GoalCompletionTests()
        let cases: [(String, () throws -> Void)] = [
            ("ordinary activity keeps its role when changing personal icons", appearance.testOrdinaryActivityStaysOrdinaryWhenChoosingPersonalIcons),
            ("personal roles survive cosmetic edits", appearance.testPersonalRolesSurviveChoosingUnrelatedIconsAndNames),
            ("explicit ordinary role persists and legacy inference remains", appearance.testExplicitOrdinaryRolePersistsAndLegacyInferenceStillWorks),
            ("daily priority totals include the whole previous day", priority.testDailyTotalsIncludeWholePreviousDay),
            ("daily priority totals respect midnight and DST", priority.testDailyTotalsClipMidnightAndRespectDST),
            ("daily priority totals follow chosen date and empty selection", priority.testDailyTotalsFollowSelectedDateAndEmptySelection),
            ("priority comparison handles empty selection and zero baseline", priority.testUnselectedAndZeroPreviousDoNotInventPercentages),
            ("priority comparison sums chosen activities across recording sources", priority.testMultiplePriorityActivitiesAndAllRecordingSources),
            ("priority comparison matches elapsed part of current week", priority.testCurrentWeekUsesSameElapsedPartAndClipsEntries),
            ("priority comparison clips at month boundaries", priority.testMonthBoundaryAndDifferentMonthLengths),
            ("priority follows IDs through renaming and archiving", priority.testPrioritySurvivesRenameAndArchiveByID),
            ("priority supports legacy and JSON SQLite persistence", priority.testLegacyAndJSONSQLitePersistence),
            ("priority changes preserve history and reset clears choices", priority.testPriorityChangesAndResetDoNotRewriteHistory),
            ("priority comparison handles year boundaries and decline", priority.testYearBoundaryAndNegativeChange),
            ("reset clears old tasks and starts with four today", completion.testResetClearsOldTasksAndStartsWithFourToday),
            ("post midnight sleep cannot move reset baseline back", completion.testPostMidnightSleepCannotMoveResetBaselineBack),
            ("reset baseline survives reopening wake and next day", completion.testResetBaselineSurvivesReopenAndWake),
            ("explicit baseline excludes earlier legacy goals", completion.testExplicitBaselineExcludesEarlierLegacySleepGoals),
            ("sleep statistics baseline survives missing markers and persistence", completion.testSleepBaselinePersistsAndCountsDaysWithoutMarkers),
            ("invalid sleep statistics start rejected", completion.testInvalidSleepStatisticsBaselineRejected),
            ("completion summary scales to a year of entries", completion.testLargeJournalDoesNotRescanEveryEntryForEveryDay),
            ("completion summary counts recurring day and week tasks", completion.testRecurringOccurrencesAndSeparateRates),
            ("completion summary respects weekly versions and archives", completion.testWeeklyVersionsAndArchivedActivities),
            ("completion summary splits DST and week boundaries", completion.testDSTAndSundayMondayBoundary),
            ("completion summary handles no goals and future goals", completion.testEmptyAndFutureGoalsHaveNoRate),
            ("completion summary includes sleep deadlines without old work days", completion.testSleepGoalsUseSleepHistoryAndActualDeadlines),
            ("completion summary handles legacy and disabled sleep goals", completion.testLegacySleepGoalsAndDisabledPlan),
            ("completion summary respects limits and observation goals", completion.testLimitsWaitForWeekEndAndObservationExcluded),
            ("completion summary recalculates after editing or deleting", completion.testEditingAndDeletingRecalculatesWithoutSavedCounters),
            ("recording modes keep legacy defaults", modes.testDefaultsAndLegacyMissingModeKeepExistingBehavior),
            ("both mode lists study and research in both paths", modes.testBothAddsStudyAndResearchToBothLists),
            ("modes override category rules and survive rename", modes.testModesOverrideOldCategoryRulesAndSurviveRename),
            ("online and offline study share goal without duplication", modes.testBothOnlineAndOfflineAddOnceToSameGoal),
            ("active session remains finishable after mode or archive change", modes.testActiveSessionStaysFinishableAfterModeChangeAndArchive),
            ("all manual stops reminders and reenabling starts fresh", modes.testAllManualStopsReminderClockAndReenableStartsFresh),
            ("rest remains a special sleep activity", modes.testRestStaysSpecialRegardlessOfMode),
            ("custom activity supports manual timing", modes.testCustomActivityCanUseManualTimer),
            ("recording mode and generic session persist", modes.testModesAndGenericSessionSurviveJSONAndSQLite),
            ("mode switches preserve existing data", modes.testSwitchingModePreservesHistoryGoalsAndPreferences),
            ("invalid mode starts and stale finishes are atomic", modes.testInvalidStartsAndWrongSessionAreAtomic),
            ("unknown recording mode import rejected", modes.testUnknownModeRejectedOnImport),
            ("quick choices exclude personal categories and preserve old history", personal.testQuickChoicesExcludePersonalCategoriesWithoutDeletingHistory),
            ("legacy personal category migration is stable", personal.testLegacyCategoryMigrationIsIdempotentAndPreservesData),
            ("exercise timer creates entry and updates daily goals", personal.testExerciseCreatesOneEntryAndUpdatesDailyGoal),
            ("late return edits both times without moving current tracking", personal.testLateReturnCanEditBothTimesWithoutMovingTrackingClock),
            ("finish uses actual past times and resumes on return", personal.testFinishCanUseActualPastTimesAndResumeOnlyOnReturn),
            ("personal timer pauses check-ins and survives recovery", personal.testPersonalTimerStopsCheckInsAndRecoversAcrossClose),
            ("personal timers preserve manual and timed pauses", personal.testManualPauseRemainsPausedAndTimedPauseDoesNotBackfill),
            ("sleep and personal sessions cannot overlap", personal.testSleepAndPersonalSessionsCannotRunTogether),
            ("personal edit and finish conflicts are atomic", personal.testEditAndFinishConflictsAreAtomic),
            ("personal cancellation and deletion preserve other entries", personal.testDeleteOnlyOwnEntryAndCancelResumesRecording),
            ("personal category rename and archive keep identity", personal.testRenamedArchivedCategoryStillUsesSameID),
            ("personal timers persist in SQLite and JSON", personal.testActiveAndCompletedSessionsPersistWithLegacyCompatibility),
            ("overnight personal activity splits report days", personal.testOvernightActivitySplitsReportsAtMidnight),
            ("invalid personal session data rejected", personal.testInvalidSessionDataAndRestTimerAreRejected),
            ("nap markers create rest and automatic goals", sleep.testNapCreatesExactRestEntryAndAutomaticGoals),
            ("sleep deadlines use minute precision and late sleep still logs rest", sleep.testMinutePrecisionAtDeadlinesAndLateSleepStillRecordsRest),
            ("night goals pair evening with following morning", sleep.testNightGoalsBelongToEveningAndFollowingMorning),
            ("after-midnight bedtime is late for previous evening", sleep.testAfterMidnightBelongsToPreviousEveningAndCannotEarnLateGoal),
            ("early wake still belongs to planned morning", sleep.testEarlyWakeBeforeMidnightStillBelongsToPlannedMorning),
            ("activity tracking suspends for sleep and resumes without backlog", sleep.testTrackingStopsDuringSleepAndResumesWithNewFiveMinuteCycle),
            ("sleep preserves manual and timed tracking pauses", sleep.testManualAndTimedPauseArePreservedAcrossSleep),
            ("sleep duplicate markers and conflicts are atomic", sleep.testRepeatedMarkersAndConflictsAreRejectedAtomically),
            ("rest category survives rename and archive", sleep.testRestCategorySurvivesRenameAndArchive),
            ("deleting sleep removes only generated rest", sleep.testDeleteSessionRemovesOnlyItsGeneratedRestAndUpdatesGoal),
            ("sleep deletion preserves manually edited activity", sleep.testManualEditsArePreservedWhenDeletingSleepSession),
            ("active and completed sleep survives SQLite and JSON", sleep.testActiveSleepAndFinishedHistoryRoundTripWithoutNetworkOrProcess),
            ("sleep keeps captured timezone and actual DST duration", sleep.testTimezoneChangesKeepOriginalDeadlinesAndDSTDuration),
            ("sleep recording works with reminders disabled", sleep.testDisabledRemindersDoNotDisableManualSleepJournal),
            ("reminder sounds at 0/10/20/30/40/50 then expires at 60", r.testSixSoundsThenExpireAtSixtySeconds),
            ("sleep reminder sounds every three seconds until 60", r.testSleepSoundsEveryThreeSecondsAndStopsAtSixty),
            ("sleep dismiss cancels three-second cadence without burst", r.testSleepDismissalStopsThreeSecondCadenceAndNoCatchupBurst),
            ("dismissed reminders stop sounds", r.testClosingOrAnsweringStopsAllFutureSounds),
            ("delayed timers never burst or extend reminder", r.testDelayedTimerDoesNotBurstOrExtendDeadline),
            ("backward clock cannot extend reminder", r.testBackwardClockCannotExtendVisibleReminder),
            ("reminder exact boundaries and duplicate callbacks", r.testBoundaryAndRepeatedTimerCallbacks),
            ("new reminders get independent lifetime", r.testNewReminderHasIndependentDeadline),
            ("sleep scheduler picks nearest daily slot", r.testSleepScheduleChoosesNearestSlotAndRollsIntoNextDay),
            ("sleep scheduler respects timezone and new year", r.testSleepScheduleUsesReportTimezoneAtYearBoundary),
            ("four fixed daily sleep times and native triggers", s.testFourFixedDailyTimesAndNativeTriggers),
            ("sleep goals reset at local midnight without auto-completion", s.testDailyResetAtLocalMidnightAndNoAutomaticCompletion),
            ("sleep confirmations are idempotent and reversible", s.testConfirmationIsIdempotentAndCanBeUnchecked),
            ("disabled sleep reminders keep history and ignore actions", s.testDisableKeepsHistoryAndIgnoresOldActions),
            ("sleep legacy JSON and SQLite preserve activity and goals", s.testLegacyDataAndRoundTripPreserveOtherGoalsAndEntries),
            ("invalid sleep data rejected", s.testInvalidDatesDuplicatesAndUnknownReminderRejected),
            ("sleep schedule follows timezone across DST", s.testDSTUsesLocalWallClock),
            ("three five-minute intervals", t.testThreeFiveMinuteIntervals),
            ("adjacent totals", t.testAdjacentAnswersTotalWithoutDoubleCounting),
            ("unknown does not continue activity", t.testUnknownDoesNotContinueLastActivity),
            ("idempotent old notification", t.testRepeatedNotificationIsIdempotent),
            ("delayed answer keeps original time", t.testDelayedAnswerKeepsOriginalTime),
            ("pause closes partial interval", t.testPauseClosesPartialAndDoesNotCountOffline),
            ("timed pause", t.testTimedPauseStartsNewCycleAtReturn),
            ("crash recovery checkpoint", t.testRecoverOnlyUntilHeartbeat),
            ("edit classification", t.testEditChangesOnlyClassification),
            ("manual time outside tracking", t.testOutsideManualEntryDoesNotChangeCoverage),
            ("overlap rejection is atomic", t.testOverlapRejectedWithoutMutation),
            ("replacement preserves surrounding data", t.testReplacingPreservesBothSides),
            ("answer fills only gaps", t.testAnswerOnlyFillsRemainingGaps),
            ("midnight clipping", t.testCrossMidnightClipping),
            ("empty coverage", t.testEmptyReportHasNoCoverage),
            ("archive and rename", t.testArchiveAndRenameKeepTotals),
            ("JSON and SQLite round trip", t.testBackupRoundTripAndRepository),
            ("invalid backup rejection", t.testInvalidBackupRejected),
            ("overlapping tracking rejection", t.testBackupOverlappingIntervalsRejected),
            ("CSV clipping and escaping", t.testCSVClipsEscapesAndNeutralizesFormula),
            ("schedule boundary", t.testScheduledBoundaryAndOfflineGap),
            ("shorter previous month", t.testCurrentMonthComparisonUsesSharedDays),
            ("daylight-saving duration", t.testDSTDayUsesActualDuration),
            ("pending interval sweep", t.testPendingSweepHandlesGapsAndLongEntries),
            ("checkpoint and process lock", t.testCheckpointAndExclusiveProcessLock),
            ("double start keeps time", t.testStartingTwiceDoesNotDiscardTime),
            ("days with data clipping", t.testDaysWithDataAreClippedAndNotDoubleCounted),
            ("recent check-in ignores missed and skipped history", t.testRecentCheckInNeverFallsBackToMissedOrSkippedIntervals),
            ("recent check-in expires quietly", t.testRecentCheckInExpiresWithoutResurfacingBacklog),
            ("all-time totals span years and archived activities", t.testAllTimeTotalsIncludeOlderYearsAndArchivedActivities),
            ("all-time report handles empty history", t.testAllTimeReportHandlesEmptyHistory),
            ("legacy goals decode as weekly", g.testLegacyWeeklyGoalDecodesWithoutPeriod),
            ("daily target update preserves weekly goal", g.testDailySaveUpsertsWithoutReplacingWeeklyGoals),
            ("daily checkbox threshold and activity filter", g.testDailyCheckCompletesOnlyAtThresholdForChosenActivity),
            ("daily checkbox resets without deleting activity", g.testDailyCheckResetsNextDayWithoutDeletingActivity),
            ("daily goals clip at local midnight", g.testDailyProgressClipsMidnightInReportTimezone),
            ("editing activity unchecks daily goal", g.testEditingActivityAutomaticallyUnchecksGoal),
            ("goal deletion and undo preserve activity", g.testDeleteAndUndoPreserveActivityAndOtherGoals),
            ("weekly deletion removes old versions", g.testDeleteWeeklyGoalDoesNotResurfaceOlderRule),
            ("invalid daily targets rejected atomically", g.testInvalidDailyTargetsAreRejectedAtomically),
            ("daily and weekly goals persist together", g.testDailyAndWeeklyGoalsRoundTripSQLite),
            ("week picker uses ISO week year", p.testWeekPickerUsesWeekYearAtNewYear),
            ("week year change clamps week 53", p.testChangingWeekYearClampsWeek53),
            ("month and year pickers normalize dates", p.testMonthAndYearSelectionNormalizeToFirstDay),
            ("period arrows advance correct boundaries", p.testPeriodArrowsAdvanceWholePeriodsAtBoundaries),
            ("weekly targets preserve past weeks and daily target", w.testWeeklyGoalVersionsPreservePastWeeksAndDailyGoal),
            ("weekly goals aggregate days and reset Monday", w.testWeeklyProgressAggregatesDaysAndResetsMonday),
            ("weekly goals split Sunday and Monday", w.testWeeklyProgressSplitsSundayAndMonday),
            ("weekly validation deletion and undo preserve data", w.testWeeklyValidationDeletionAndUndoPreserveActivity)
        ]
        for (name, test) in cases {
            let before = failures.count
            do { try test() } catch { failures.append("\(name): \(error)") }
            print("\(before == failures.count ? "PASS" : "FAIL") \(name)")
        }
        // A realistic full year has ~105k five-minute intervals; catch quadratic regressions.
        var j = Journal()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for index in 0..<105_120 {
            let start = base.addingTimeInterval(Double(index * 300)), end = start.addingTimeInterval(300)
            j.intervals.append(Span(start: start, end: end))
            if index % 10 != 0 { j.entries.append(Entry(start: start, end: end, activityID: j.activities[index % 8].id)) }
        }
        let began = Date()
        let pending = Engine.pendingIntervals(j)
        let report = Reports.summarize(j, range: DateInterval(start: base, end: base.addingTimeInterval(365 * 86400)))
        XCTAssertEqual(pending.count, 10_512)
        XCTAssertEqual(report.coverage!, 0.9, accuracy: 0.00001)
        print(String(format: "Year dataset: %d intervals, aggregation + pending %.3fs", j.intervals.count, Date().timeIntervalSince(began)))
        if failures.isEmpty { print("All \(cases.count + 1) checks passed.") }
        else { failures.forEach { fputs($0 + "\n", stderr) }; exit(1) }
    }
}

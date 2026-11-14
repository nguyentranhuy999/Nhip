import AppKit
import SwiftUI
import UserNotifications
import ServiceManagement
import UniformTypeIdentifiers
import NhipCore

@MainActor final class AppModel: ObservableObject {
    static let shared = AppModel()
    @Published var journal = Journal()
    @Published var error: String?
    @Published var notice: String?
    @Published var authorization: UNAuthorizationStatus = .notDetermined
    @Published var systemSuspended = false
    @Published var selectedInterval: UUID?
    @Published var previewInterval: Span?
    @Published var loginEnabled = false
    @Published var settingsTab = 3
    @Published var dashboardSettingsPage: DashboardPage = .day
    @Published var showAllTimeSummary = true
    @Published var showGoals = false
    @Published var showDeadlines = false
    @Published var showPersonalActivities = false
    @Published var activeSleepAlert: SleepAlert?
    private(set) var repository: Repository?
    let dataDirectory: URL
    let demo: Bool
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var lastWall = Date()
    private var lastUptime = ProcessInfo.processInfo.systemUptime
    private var undoState: Journal?
    private var undoBaselineIntervals: Set<UUID> = []
    private(set) var storageFailed = false
    private var sleepSmokeTest: Bool { demo && CommandLine.arguments.contains("--smoke-sleep") && CommandLine.arguments.contains("--data-dir") }
    private lazy var sleepNotifications = SleepNotifications(demo: demo, diagnosticsURL: sleepSmokeTest ? dataDirectory.appendingPathComponent("sleep-schedule-check.json") : nil)
    private let checkInSuccessSound = CheckInSuccessSound()
    private var configuredSleepSchedule: SleepSchedule?
    private lazy var quickAlert = makeAlertController(kind: "quick")
    private lazy var sleepAlert = makeAlertController(kind: "sleep")
    private var alertEvents: [[String: Any]] = []

    init() {
        demo = CommandLine.arguments.contains("--demo")
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--data-dir"), args.count > index + 1 {
            dataDirectory = URL(fileURLWithPath: args[index + 1], isDirectory: true)
        } else {
            dataDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(demo ? "Nhip-Demo" : "Nhip", isDirectory: true)
        }
        do {
            let repo = try Repository(url: dataDirectory.appendingPathComponent("journal.sqlite"))
            repository = repo
            journal = try repo.load()
            GoalReports.prepareDailyPlans(&journal)
            PersonalTracking.prepare(&journal)
            DashboardSelection.prepare(&journal)
            SleepPlan.prepareStatistics(journal: &journal)
            Engine.recover(&journal)
            if demo && journal.entries.isEmpty && !args.contains("--smoke-reminder") { seedDemo() }
            try repo.save(journal)
        } catch {
            repository = nil; storageFailed = true; self.error = error.localizedDescription
        }
        loginEnabled = SMAppService.mainApp.status == .enabled
    }

    var activeActivities: [Activity] { journal.activities.filter { !$0.archived } }
    var quickActivities: [Activity] { PersonalTracking.quickActivities(journal) }
    var currentInterval: Span? {
        if let previewInterval { return previewInterval }
        if let id = selectedInterval { return journal.intervals.first { $0.id == id } }
        return Engine.recentCheckIn(journal, at: Date())
    }
    var userName: String {
        let saved = journal.preferences.userName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !saved.isEmpty { return saved }
        let systemName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        return systemName.isEmpty ? "bạn" : systemName
    }
    var status: String {
        if storageFailed { return "Không thể mở dữ liệu" }
        if let session = journal.sleepHistory?.active { return session.kind == .nap ? "Đang ngủ trưa" : "Đang ngủ đêm" }
        if let session = journal.personalHistory?.active { return "Đang ghi nhận: \(journal.activity(session.activityID)?.name ?? "hoạt động")" }
        if systemSuspended { return "Tạm dừng theo máy" }
        if let until = journal.runtime.pauseUntil { return "Tạm dừng đến \(time(until))" }
        if !journal.runtime.enabled { return "Đã tạm dừng" }
        if quickActivities.isEmpty { return "Chỉ ghi nhận thủ công" }
        if journal.runtime.segmentStart == nil { return "Đang chờ lịch" }
        return "Đang theo dõi"
    }
    func time(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "vi_VN"); f.timeZone = journal.preferences.calendar.timeZone
        f.dateFormat = "HH:mm"; return f.string(from: date)
    }
    func dateLabel(_ date: Date, format: String = "dd/MM/yyyy") -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "vi_VN"); f.timeZone = journal.preferences.calendar.timeZone
        f.dateFormat = format; return f.string(from: date)
    }
    func launch() {
        guard !storageFailed else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationDelegate.shared
        let same = UNNotificationAction(identifier: "SAME", title: "Giống lần trước", options: [])
        let choose = UNNotificationAction(identifier: "CHOOSE", title: "Chọn hoạt động", options: [.foreground])
        center.setNotificationCategories(SleepNotifications.categories.union([UNNotificationCategory(identifier: "CHECKIN", actions: [choose, same], intentIdentifiers: [])]))
        refreshAuthorization()
        if SleepPlan.isEnabled(journal) && !demo { requestSleepAuthorizationIfNeeded() }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in AppModel.shared.refreshAuthorization() }
        })
        observeWorkspace(NSWorkspace.willSleepNotification) { $0.suspend() }
        observeWorkspace(NSWorkspace.screensDidSleepNotification) { $0.suspend() }
        observeWorkspace(NSWorkspace.didWakeNotification) { $0.wakeIfAvailable() }
        observeWorkspace(NSWorkspace.screensDidWakeNotification) { $0.wakeIfAvailable() }
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { _ in Task { @MainActor in AppModel.shared.suspend() } })
        observers.append(distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in Task { @MainActor in AppModel.shared.resumeSystem() } })
        // One low-frequency heartbeat, plus one exact deadline timer per interval.
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in Task { @MainActor in AppModel.shared.advance() } }
        advance()
        // Explicit isolated UI check: exercise the real five-minute deadline after 3 seconds.
        if demo && CommandLine.arguments.contains("--smoke-reminder") && CommandLine.arguments.contains("--data-dir") && journal.intervals.isEmpty {
            journal.preferences.onboarded = true
            Engine.start(&journal, at: Date().addingTimeInterval(-297))
            persist(); scheduleNext()
        }
    }
    private func observeWorkspace(_ name: NSNotification.Name, action: @escaping @MainActor (AppModel) -> Void) {
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in Task { @MainActor in action(AppModel.shared) } })
    }
    private var deadlineTimer: Timer?
    func advance() {
        guard !storageFailed, !systemSuspended else { return }
        let now = Date(), uptime = ProcessInfo.processInfo.systemUptime
        let previousIntervalCount = journal.intervals.count
        let clockDrift = abs(now.timeIntervalSince(lastWall) - (uptime - lastUptime))
        if clockDrift > 10 { sleepNotifications.rearm() }
        if clockDrift > 10, let checkpoint = journal.runtime.heartbeat {
            Engine.close(&journal, at: checkpoint)
            if journal.runtime.enabled && journal.runtime.pauseUntil == nil && journal.preferences.allows(now) { Engine.begin(&journal, at: now) }
        }
        lastWall = now; lastUptime = uptime
        let previousRuntime = journal.runtime
        let completed = Engine.tick(&journal, at: now)
        if previousIntervalCount != journal.intervals.count { persist() }
        else if previousRuntime != journal.runtime {
            do { try repository?.saveRuntime(journal.runtime) }
            catch { self.error = error.localizedDescription; storageFailed = true }
        }
        scheduleNext()
        if let latest = completed.last { presentReminder(latest) }
    }
    func suspend() {
        guard !systemSuspended else { return }
        advance(); Engine.close(&journal, at: Date()); systemSuspended = true
        persist(); cancelReminder()
        WindowManager.shared.quick?.close()
        dismissSleepAlert()
    }
    func wakeIfAvailable() {
        // A wake may occur before the login screen is unlocked; wait for session state.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            if let session = CGSessionCopyCurrentDictionary() as? [String: Any], session["CGSSessionScreenIsLocked"] as? Bool == true { return }
            self.resumeSystem()
        }
    }
    func resumeSystem() {
        systemSuspended = false; lastWall = Date(); lastUptime = ProcessInfo.processInfo.systemUptime
        advance()
        sleepNotifications.rearm()
    }
    func start() {
        guard !storageFailed else { return }
        journal.preferences.onboarded = true
        Engine.start(&journal, at: Date()); persist(); scheduleNext()
    }
    func pause(_ minutes: Int? = nil) {
        Engine.pause(&journal, at: Date(), minutes: minutes); persist(); scheduleNext()
        WindowManager.shared.quick?.close()
    }
    func prepareToTerminate() async {
        if !storageFailed { advance(); Engine.close(&journal, at: Date()); persist() }
        cancelReminder()
        quickAlert.cancel(); checkInSuccessSound.stop(); dismissSleepAlert()
        await sleepNotifications.prepareToTerminate()
    }
    func persist() {
        guard !storageFailed else { return }
        do { try repository?.save(journal) }
        catch { self.error = error.localizedDescription; storageFailed = true; cancelReminder() }
    }
    @discardableResult func perform(_ operation: (inout Journal) throws -> Void, replacingHistory: Bool = false) -> Bool {
        guard !storageFailed else { return false }
        do {
            var draft = journal; try operation(&draft); GoalReports.prepareDailyPlans(&draft); PersonalTracking.prepare(&draft); DashboardSelection.prepare(&draft); SleepPlan.prepareStatistics(journal: &draft)
            if PersonalTracking.quickActivities(draft).isEmpty { Engine.close(&draft, at: Date()) }
            try Engine.validate(draft)
            if !replacingHistory { try HistoryProtection.validateChange(from: journal, to: draft) }
            try repository?.save(draft); undoState = journal; undoBaselineIntervals = Set(draft.intervals.map(\.id)); journal = draft
            syncSleepReminders()
            if quickActivities.isEmpty { WindowManager.shared.quick?.close(); cancelReminder() }
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func undo() {
        guard let previous = undoState else { return }
        var restored = previous; restored.runtime = journal.runtime
        if restored.isRecordingPersonalActivity {
            restored.runtime.segmentStart = nil; restored.runtime.nextDue = nil
        }
        let oldIDs = Set(restored.intervals.map(\.id))
        restored.intervals += journal.intervals.filter { !undoBaselineIntervals.contains($0.id) && !oldIDs.contains($0.id) }
        do { try Engine.validate(restored); try HistoryProtection.validateChange(from: journal, to: restored); try repository?.save(restored); journal = restored; undoState = nil; notice = "Đã hoàn tác."; syncSleepReminders(); advance() }
        catch { self.error = error.localizedDescription }
    }
    @discardableResult func answer(_ span: Span, activityID: UUID, note: String = "") -> Bool {
        guard quickActivities.contains(where: { $0.id == activityID }),
              !Engine.isAnswered(journal, interval: span) else { return false }
        guard perform({ try Engine.answer(&$0, intervalID: span.id, activityID: activityID, note: note) }) else { return false }
        quickAlert.cancel()
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["nhip.checkin"])
        if selectedInterval == span.id { WindowManager.shared.quick?.close() }
        if journal.preferences.isCheckInSuccessSoundEnabled { checkInSuccessSound.play() }
        return true
    }
    func previewCheckInSuccessSound() { checkInSuccessSound.play() }
    func confirmPreviewCheckIn() {
        guard previewInterval != nil else { return }
        quickAlert.cancel()
        WindowManager.shared.quick?.close()
        if journal.preferences.isCheckInSuccessSoundEnabled { checkInSuccessSound.play() }
    }
    func skip(_ span: Span) {
        perform { if !$0.skipped.contains(span.id) { $0.skipped.append(span.id) } }
        selectedInterval = nil
        WindowManager.shared.quick?.close()
    }
    func updatePreferences(_ preferences: Preferences, sleepSchedule: SleepSchedule? = nil) {
        guard !storageFailed else { return }
        advance(); Engine.close(&journal, at: Date())
        perform {
            $0.preferences = preferences
            if let sleepSchedule { try SleepPlan.setSchedule(sleepSchedule, journal: &$0) }
        }
        advance()
    }
    func refreshAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in Task { @MainActor in self.authorization = settings.authorizationStatus; self.syncSleepReminders() } }
    }
    func syncSleepReminders() {
        guard !storageFailed else { return }
        let schedule = SleepPlan.schedule(journal)
        if !SleepPlan.isEnabled(journal) || (configuredSleepSchedule != nil && configuredSleepSchedule != schedule) { dismissSleepAlert() }
        configuredSleepSchedule = schedule
        sleepNotifications.reconcile(enabled: SleepPlan.isEnabled(journal), calendar: journal.preferences.calendar,
                                     authorized: authorization == .authorized || authorization == .provisional, schedule: schedule,
                                     onReminder: { [weak self] reminder, date, preview in
                                         self?.presentSleepAlert(reminder, date: date, preview: preview)
                                     })
    }
    func toggleSleepReminders(_ enabled: Bool) {
        perform { SleepPlan.setEnabled(enabled, journal: &$0) }
        if SleepPlan.isEnabled(journal) { requestSleepAuthorizationIfNeeded() }
    }
    private func requestSleepAuthorizationIfNeeded() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard SleepPlan.isEnabled(journal) else { return }
            if settings.authorizationStatus == .notDetermined { requestAuthorization() }
            else { authorization = settings.authorizationStatus; syncSleepReminders() }
        }
    }
    func setSleeping(_ sleeping: Bool, kind: SleepKind) {
        let now = Date()
        let start = journal.sleepHistory?.active?.start
        let saved = perform {
            if sleeping { try SleepTracking.start(&$0, kind: kind, at: now) }
            else { try SleepTracking.wake(&$0, at: now) }
        }
        guard saved else { return }
        WindowManager.shared.quick?.close(); dismissSleepAlert(); scheduleNext()
        notice = sleeping ? "Đã ghi giờ đi ngủ." : "Đã ghi \(durationText(now.timeIntervalSince(start ?? now))) Nghỉ ngơi."
    }
    func deleteSleepSession(_ session: SleepSession) {
        if perform({ try SleepTracking.delete(&$0, sessionID: session.id, at: Date()) }) {
            scheduleNext(); notice = "Đã xóa lần ghi nhận giấc ngủ."
        }
    }
    func setRecordingMode(_ mode: ActivityRecordingMode, activityID: UUID) {
        advance()
        if perform({ try PersonalTracking.setRecordingMode(&$0, activityID: activityID, mode: mode) }) { advance() }
    }
    func startPersonalActivity(_ activityID: UUID) {
        if perform({ try PersonalTracking.start(&$0, activityID: activityID, at: Date()) }) {
            WindowManager.shared.quick?.close(); scheduleNext()
            notice = "Đã bắt đầu \(journal.activity(activityID)?.name.lowercased() ?? "hoạt động")."
        }
    }
    func savePersonalActivity(_ candidate: Journal) -> Bool {
        guard perform({ $0 = candidate }) else { return false }
        scheduleNext(); notice = "Đã lưu thời gian hoạt động."
        return true
    }
    func deletePersonalActivity(_ session: PersonalActivitySession) {
        if perform({ try PersonalTracking.delete(&$0, sessionID: session.id, at: Date()) }) {
            scheduleNext(); notice = "Đã xóa lần ghi nhận \(journal.activity(session.activityID)?.name.lowercased() ?? "hoạt động")."
        }
    }
    func previewSleepReminder() {
        syncSleepReminders(); sleepNotifications.preview()
        notice = "Lời nhắc ngủ thử sẽ đến sau 3 giây."
    }
    func presentSleepAlert(_ reminder: SleepReminder, date: Date, preview: Bool) {
        guard !storageFailed, !systemSuspended, SleepPlan.isEnabled(journal),
              Date().timeIntervalSince(date) < ReminderLifetime.duration else { return }
        if !preview {
            let goalDate = SleepPlan.goalDate(for: reminder, scheduledAt: date, journal: journal)
            if SleepPlan.isComplete(reminder, journal: journal, on: goalDate) { return }
        }
        activeSleepAlert = SleepAlert(reminder: reminder, date: date, preview: preview)
        WindowManager.shared.showSleep()
        if preview { WindowManager.shared.sleep?.makeKeyAndOrderFront(nil) }
        sleepAlert.start(soundEnabled: { true }, soundInterval: 3) { [weak self] in self?.dismissSleepAlert() }
    }
    func dismissSleepAlert() {
        sleepAlert.cancel(); activeSleepAlert = nil
        WindowManager.shared.sleep?.close()
    }
    func sleepAlertDidClose() { sleepAlert.cancel(); activeSleepAlert = nil }
    func quickAlertDidClose() {
        quickAlert.cancel(); previewInterval = nil; selectedInterval = nil
    }
    private func startQuickAlert() {
        quickAlert.start(soundEnabled: { [weak self] in self?.journal.preferences.sound ?? false }, soundInterval: 3) {
            WindowManager.shared.quick?.close()
        }
    }
    private func makeAlertController(kind: String) -> ReminderAlertController {
        let controller = ReminderAlertController()
        if demo && CommandLine.arguments.contains("--smoke-alerts") && CommandLine.arguments.contains("--data-dir") {
            controller.onEvent = { [weak self] event, elapsed in
                guard let self else { return }
                alertEvents.append(["kind": kind, "event": event, "elapsed": elapsed, "at": Date().timeIntervalSince1970])
                do {
                    try JSONSerialization.data(withJSONObject: alertEvents, options: [.prettyPrinted, .sortedKeys])
                        .write(to: dataDirectory.appendingPathComponent("alert-events.json"), options: .atomic)
                } catch { NSLog("Nhịp: %@", error.localizedDescription) }
            }
        }
        return controller
    }
    func requestAuthorization() {
        Task {
            do { _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]); refreshAuthorization(); scheduleNext() }
            catch { self.error = error.localizedDescription }
        }
    }
    func sendTestNotification() {
        Task {
            do {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                refreshAuthorization()
                guard allowed else { notice = "Hãy cho phép thông báo Nhịp trong System Settings → Notifications."; return }
                let content = UNMutableNotificationContent()
                content.title = "Nhịp · Thông báo thử"
                content.body = "Thông báo đã sẵn sàng. Mỗi chu kỳ, Nhịp sẽ hỏi bạn vừa làm gì."
                content.userInfo = ["test": true]
                if journal.preferences.sound { content.sound = .default }
                try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "nhip.test", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)))
                notice = "Thông báo thử sẽ đến sau 3 giây; Focus có thể ẩn banner."
            } catch { self.error = error.localizedDescription }
        }
    }
    func scheduleNext() {
        deadlineTimer?.invalidate(); deadlineTimer = nil
        guard !systemSuspended, !storageFailed, let due = journal.runtime.nextDue else {
            cancelReminder(); return
        }
        let delay = max(0.1, due.timeIntervalSinceNow)
        deadlineTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in Task { @MainActor in AppModel.shared.advance() } }
    }
    func previewReminder() {
        guard !quickActivities.isEmpty else {
            error = "Chọn Nhắc định kỳ hoặc Cả hai cho ít nhất một hoạt động trong Cài đặt → Hoạt động."; return
        }
        let end = Date()
        previewInterval = Span(start: end.addingTimeInterval(-Double(journal.preferences.intervalMinutes * 60)), end: end)
        WindowManager.shared.showQuick(automatic: true)
        // The preview is explicitly requested, so let its activity buttons receive keyboard focus.
        WindowManager.shared.quick?.makeKeyAndOrderFront(nil)
        startQuickAlert()
    }
    func presentReminder(_ span: Span) {
        guard !systemSuspended, !storageFailed, !quickActivities.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["nhip.checkin"])
        center.removeDeliveredNotifications(withIdentifiers: ["nhip.checkin"])
        // Each deadline asks only about the most recent interval; missed intervals stay quiet.
        previewInterval = nil
        selectedInterval = span.id
        WindowManager.shared.showQuick(automatic: true)
        startQuickAlert()
    }
    func cancelReminder() {
        deadlineTimer?.invalidate(); deadlineTimer = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nhip.checkin"])
    }
    func handleNotification(_ response: UNNotificationResponse) {
        advance()
        let info = response.notification.request.content.userInfo
        if let raw = info["sleepReminder"] as? String, SleepReminder(rawValue: raw) != nil {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
            // Notifications are reminders only, including actions on an old delivered banner.
            return
        }
        guard let start = info["start"] as? Double, let end = info["end"] as? Double,
              let span = journal.intervals.first(where: { abs($0.start.timeIntervalSince1970 - start) < 1 && abs($0.end.timeIntervalSince1970 - end) < 1 }) else {
            WindowManager.shared.showDashboard(); return
        }
        guard Engine.recentCheckIn(journal, at: Date())?.id == span.id else { WindowManager.shared.showDashboard(); return }
        selectedInterval = span.id
        if response.actionIdentifier == "SAME", let id = journal.runtime.lastActivityID, quickActivities.contains(where: { $0.id == id }), !Engine.isAnswered(journal, interval: span) {
            answer(span, activityID: id)
        } else { WindowManager.shared.showQuick(); startQuickAlert() }
    }
    func foregroundNotification(_ notification: UNNotification) -> UNNotificationPresentationOptions {
        let info = notification.request.content.userInfo
        if let raw = info["sleepReminder"] as? String, let reminder = SleepReminder(rawValue: raw) {
            presentSleepAlert(reminder, date: notification.date, preview: info["sleepPreview"] as? Bool == true)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
            return []
        }
        return [.banner, .list, .sound]
    }
    func toggleLogin(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if value && !loginEnabled { notice = "Hãy cho phép Nhịp trong System Settings → General → Login Items." }
        } catch { self.error = error.localizedDescription; loginEnabled = SMAppService.mainApp.status == .enabled }
    }
    func exportCSV(range: DateInterval) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Nhip-\(dateLabel(range.start).replacingOccurrences(of: "/", with: "-" )).csv"; panel.allowedContentTypes = [.commaSeparatedText]
        if panel.runModal() == .OK, let url = panel.url {
            do { try Reports.csv(journal, range: range).write(to: url, atomically: true, encoding: .utf8); notice = "Đã xuất CSV." }
            catch { self.error = error.localizedDescription }
        }
    }
    @discardableResult func backup(to target: URL? = nil) -> Bool {
        var url = target
        if url == nil {
            let panel = NSSavePanel(); panel.nameFieldStringValue = "Nhip-backup.json"; panel.allowedContentTypes = [.json]
            guard panel.runModal() == .OK else { return false }; url = panel.url
        }
        guard let url else { return false }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(journal).write(to: url, options: .atomic)
            if target == nil { notice = "Đã sao lưu toàn bộ dữ liệu." }; return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func restore() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            var imported = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: url)); try Engine.validate(imported)
            let alert = NSAlert(); alert.messageText = "Thay thế dữ liệu bằng bản sao lưu?"
            alert.informativeText = "Bản sao lưu có \(imported.entries.count) bản ghi, \(imported.activities.count) danh mục. Dữ liệu hiện tại sẽ được sao lưu tự động trước khi thay thế."
            alert.addButton(withTitle: "Khôi phục"); alert.addButton(withTitle: "Hủy")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            let rescue = dataDirectory.appendingPathComponent("before-restore-\(Int(Date().timeIntervalSince1970)).json")
            guard backup(to: rescue) else { return }
            imported.runtime = Runtime()
            guard perform({ $0 = imported }, replacingHistory: true) else { return }; cancelReminder(); notice = "Đã khôi phục. Bản cũ: \(rescue.lastPathComponent)"
        } catch { self.error = error.localizedDescription }
    }
    func resetData() {
        let alert = NSAlert(); alert.alertStyle = .warning; alert.messageText = "Xóa toàn bộ lịch sử và cài đặt?"
        alert.informativeText = "Thao tác này xóa dữ liệu trong ứng dụng. Các file CSV/JSON đã xuất vẫn còn."
        alert.addButton(withTitle: "Xóa toàn bộ"); alert.addButton(withTitle: "Hủy")
        if alert.runModal() == .alertFirstButtonReturn {
            cancelReminder(); perform({ $0.reset() }, replacingHistory: true); undoState = nil
        }
    }
    private func seedDemo() {
        journal.preferences.onboarded = true
        let c = journal.preferences.calendar, today = c.startOfDay(for: Date())
        for offset in 0..<400 {
            let day = c.date(byAdding: .day, value: -offset, to: today)!
            guard offset > 0 else { continue }
            for index in 0..<5 {
                let start = c.date(byAdding: .minute, value: 8 * 60 + index * 80, to: day)!
                let end = start.addingTimeInterval(Double(25 + (offset * 7 + index * 13) % 45) * 60)
                journal.intervals.append(Span(start: start, end: end))
                if (offset + index) % 11 != 0 {
                    journal.entries.append(Entry(start: start, end: end, activityID: journal.activities[(index + offset / 3) % 7].id, note: "Dữ liệu minh họa", source: "demo"))
                }
            }
        }
        let now = Date()
        for i in 0..<6 {
            let start = now.addingTimeInterval(Double(-6 + i) * 300), end = start.addingTimeInterval(300)
            journal.intervals.append(Span(start: start, end: end))
            if i < 5 { journal.entries.append(Entry(start: start, end: end, activityID: journal.activities[i % 3].id, source: "demo")) }
        }
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in completionHandler(AppModel.shared.foregroundNotification(notification)) }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in AppModel.shared.handleNotification(response); completionHandler() }
    }
}

import SwiftUI
import AppKit
import NhipCore

@main struct NhipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = AppModel.shared
    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 12) {
                Label("Nhịp", systemImage: "waveform.path").font(.title2.bold())
                Label(model.status, systemImage: model.journal.runtime.enabled ? "record.circle" : "pause.circle").foregroundStyle(.secondary)
                if let next = model.journal.runtime.nextDue { Text("Nhắc tiếp: \(model.time(next))").font(.caption) }
                Divider()
                Button("Tổng kết tất cả thời gian") { model.showPersonalActivities = false; model.showGoals = false; model.showAllTimeSummary = true; WindowManager.shared.showDashboard() }
                Button("Mục tiêu") { model.showPersonalActivities = false; model.showAllTimeSummary = false; model.showGoals = true; WindowManager.shared.showDashboard() }
                Button("Hoạt động cá nhân") { model.showAllTimeSummary = false; model.showGoals = false; model.showPersonalActivities = true; WindowManager.shared.showDashboard() }
                Button("Dashboard") { WindowManager.shared.showDashboard() }.keyboardShortcut("d")
                Divider()
                Button("Bắt đầu / Tiếp tục") { model.start() }
                Menu("Tạm dừng") {
                    ForEach([15,30,60], id: \.self) { minutes in Button("\(minutes) phút") { model.pause(minutes) } }
                    Button("Đến khi bật lại") { model.pause() }
                }
                Button("Cài đặt…") { WindowManager.shared.showSettings() }
                Divider()
                Button("Thoát Nhịp") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }.padding(18).frame(width: 270)
        } label: { Image(systemName: model.journal.runtime.enabled ? "waveform.path" : "pause.circle") }
        .menuBarExtraStyle(.window)
        Settings { PreferencesView(model: model).frame(width: 750, height: 650) }
    }
}

@MainActor final class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()
    var dashboard: NSWindow?
    var quick: NSWindow?
    var sleep: NSWindow?
    var settings: NSWindow?
    func showDashboard() {
        if dashboard == nil { dashboard = makeWindow(title: "Nhịp · Nhật ký thời gian", size: NSSize(width: 1180, height: 820), view: DashboardView(model: .shared), resizable: true) }
        reveal(dashboard!)
    }
    func showQuick(automatic: Bool = false) {
        if !automatic { AppModel.shared.previewInterval = nil }
        if quick == nil {
            let panel = ReminderPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 570), styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "Nhịp · Ghi nhận nhanh"
            panel.isReleasedWhenClosed = false; panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: QuickCheckInView(model: .shared).environment(\.locale, Locale(identifier: "vi_VN")))
            panel.delegate = self
            quick = panel
        }
        if quick?.isVisible != true {
            let mouse = NSEvent.mouseLocation
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main {
                let frame = screen.visibleFrame
                quick!.setFrameTopLeftPoint(NSPoint(x: max(frame.minX, frame.maxX - 460), y: frame.maxY - 18))
            }
        }
        if automatic { quick!.orderFrontRegardless() }
        else { reveal(quick!) }
    }
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === quick {
            AppModel.shared.quickAlertDidClose()
        }
        if let window = notification.object as? NSWindow, window === sleep {
            AppModel.shared.sleepAlertDidClose()
        }
    }
    func showSleep() {
        if sleep == nil {
            let panel = ReminderPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 130), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "Nhịp · Ngủ & thức dậy"
            panel.isReleasedWhenClosed = false; panel.hidesOnDeactivate = false
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
            panel.ignoresMouseEvents = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: SleepReminderView(model: .shared).environment(\.locale, Locale(identifier: "vi_VN")))
            panel.delegate = self; sleep = panel
        }
        if sleep?.isVisible != true {
            let mouse = NSEvent.mouseLocation
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main {
                let frame = screen.visibleFrame
                sleep!.setFrameTopLeftPoint(NSPoint(x: frame.minX + 20, y: frame.maxY - 18))
            }
        }
        sleep!.orderFrontRegardless()
    }
    func showSettings() {
        if settings == nil { settings = makeWindow(title: "Cài đặt Nhịp", size: NSSize(width: 780, height: 720), view: PreferencesView(model: .shared), resizable: true) }
        reveal(settings!)
    }
    private func makeWindow<V: View>(title: String, size: NSSize, view: V, resizable: Bool) -> NSWindow {
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if resizable { style.insert(.resizable) }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: style, backing: .buffered, defer: false)
        window.title = title; window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view.environment(\.locale, Locale(identifier: "vi_VN")))
        window.minSize = NSSize(width: min(size.width, 900), height: min(size.height, 640)); window.center()
        window.setFrameAutosaveName(title)
        return window
    }
    private func reveal(_ window: NSWindow) { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
}

final class ReminderPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var terminating = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in AppModel.shared.launch(); WindowManager.shared.showDashboard() }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            AppModel.shared.showGoals = false
            AppModel.shared.showPersonalActivities = false
            AppModel.shared.showAllTimeSummary = true
            WindowManager.shared.showDashboard()
        }
        return false
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminating { return .terminateLater }
        terminating = true
        Task { @MainActor in
            await AppModel.shared.prepareToTerminate()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

extension Color {
    init(hex: String) {
        let number = UInt64(hex, radix: 16) ?? 0x6366F1
        self.init(red: Double((number >> 16) & 255) / 255, green: Double((number >> 8) & 255) / 255, blue: Double(number & 255) / 255)
    }
}

struct FeedbackModifier: ViewModifier {
    @ObservedObject var model: AppModel
    func body(content: Content) -> some View {
        content.alert("Không thể hoàn tất", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("Đóng", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
}

struct Card<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)
            content
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.primary.opacity(0.05)))
    }
}

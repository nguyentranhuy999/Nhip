import AppKit
import NhipCore

@MainActor final class ReminderAlertController {
    private var lifetime: ReminderLifetime?
    private var timer: Timer?
    private var expiration: (() -> Void)?
    private var soundEnabled: () -> Bool = { true }
    private var sound: NSSound?
    private var generation = 0
    var onEvent: ((String, Double) -> Void)?

    func start(soundEnabled: @escaping () -> Bool, soundInterval: TimeInterval = ReminderLifetime.soundInterval, onExpire: @escaping () -> Void) {
        cancel()
        self.soundEnabled = soundEnabled; expiration = onExpire
        lifetime = ReminderLifetime(at: Date(), uptime: ProcessInfo.processInfo.systemUptime, soundInterval: soundInterval)
        onEvent?("start", 0)
        advance()
    }
    private func advance() {
        guard var lifetime else { return }
        timer?.invalidate(); timer = nil
        let now = Date(), uptime = ProcessInfo.processInfo.systemUptime
        let result = lifetime.step(at: now, uptime: uptime)
        self.lifetime = lifetime
        let elapsed = lifetime.elapsed(at: now, uptime: uptime)
        if result.expired {
            let callback = expiration
            onEvent?("expire", elapsed)
            cancel(log: false); callback?(); return
        }
        if result.sound && soundEnabled() {
            sound?.stop()
            sound = NSSound(contentsOf: URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff"), byReference: true)
            if sound?.play() == true { onEvent?("sound", elapsed) }
            else { NSSound.beep(); onEvent?("sound-fallback", elapsed) }
        }
        if let delay = lifetime.nextDelay(at: Date(), uptime: ProcessInfo.processInfo.systemUptime) {
            let generation = generation
            let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.generation == generation else { return }
                    self.advance()
                }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    func cancel(log: Bool = true) {
        generation += 1
        if log, let lifetime, lifetime.isActive {
            onEvent?("cancel", lifetime.elapsed(at: Date(), uptime: ProcessInfo.processInfo.systemUptime))
        }
        timer?.invalidate(); timer = nil
        lifetime?.cancel(); lifetime = nil; expiration = nil
        sound?.stop(); sound = nil
    }
}

struct SleepAlert: Identifiable {
    let id = UUID()
    let reminder: SleepReminder
    let date: Date
    let preview: Bool
}

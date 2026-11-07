import Foundation

/// A single visible reminder. Missed sounds are never replayed in a burst.
public struct ReminderLifetime {
    public static let duration: TimeInterval = 60
    public static let soundInterval: TimeInterval = 10
    private let startedAt: Date
    private let startedUptime: TimeInterval
    private var lastSoundSlot = -1
    public private(set) var isActive = true
    public init(at date: Date, uptime: TimeInterval) { startedAt = date; startedUptime = uptime }
    public func elapsed(at date: Date, uptime: TimeInterval) -> TimeInterval {
        max(0, date.timeIntervalSince(startedAt), uptime - startedUptime)
    }
    public mutating func step(at date: Date, uptime: TimeInterval) -> (sound: Bool, expired: Bool) {
        guard isActive else { return (false, false) }
        let elapsed = elapsed(at: date, uptime: uptime)
        guard elapsed < Self.duration else { isActive = false; return (false, true) }
        let slot = Int(elapsed / Self.soundInterval)
        guard slot > lastSoundSlot else { return (false, false) }
        lastSoundSlot = slot
        return (true, false)
    }
    public func nextDelay(at date: Date, uptime: TimeInterval) -> TimeInterval? {
        guard isActive else { return nil }
        let elapsed = elapsed(at: date, uptime: uptime)
        return max(0.001, min(Self.duration, Double(lastSoundSlot + 1) * Self.soundInterval) - elapsed)
    }
    public mutating func cancel() { isActive = false }
}

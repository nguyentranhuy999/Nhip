import Foundation

public struct SleepSchedule: Codable, Equatable, Sendable {
    public var nightSleep = 0
    public var morningWake = 7 * 60
    public var napSleep = 12 * 60 + 30
    public var napWake = 13 * 60 + 30
    public init() {}
    public subscript(_ reminder: SleepReminder) -> Int {
        get {
            switch reminder { case .nightSleep: return nightSleep; case .morningWake: return morningWake; case .napSleep: return napSleep; case .napWake: return napWake }
        }
        set {
            switch reminder { case .nightSleep: nightSleep = newValue; case .morningWake: morningWake = newValue; case .napSleep: napSleep = newValue; case .napWake: napWake = newValue }
        }
    }
    public var nightBedtimeIsNextDay: Bool { nightSleep < 12 * 60 }
    public func timeLabel(for reminder: SleepReminder) -> String {
        String(format: "%02d:%02d", self[reminder] / 60, self[reminder] % 60)
    }
    public func validate() throws {
        let values = SleepReminder.allCases.map { self[$0] }
        guard values.allSatisfy({ (0..<1440).contains($0) }) else {
            throw JournalError.invalid("Giờ nhắc ngủ phải nằm trong khoảng 00:00–23:59.")
        }
        guard napWake > napSleep else {
            throw JournalError.invalid("Giờ thức dậy sau ngủ trưa phải sau giờ ngủ trưa.")
        }
        guard !nightBedtimeIsNextDay || morningWake > nightSleep else {
            throw JournalError.invalid("Khi ngủ đêm sau nửa đêm, giờ thức dậy buổi sáng phải sau giờ đi ngủ.")
        }
        guard Set(values).count == values.count else {
            throw JournalError.invalid("Hãy chọn các giờ nhắc khác nhau để lời nhắc không trùng nhau.")
        }
    }
}

import Foundation

public struct DeadlineTarget: Codable, Equatable, Identifiable {
    public var activityID: UUID
    public var minutes: Int
    public var id: UUID { activityID }
    public init(activityID: UUID, minutes: Int) { self.activityID = activityID; self.minutes = minutes }
    public var seconds: Double { Double(minutes) * 60 }
}

public struct DeadlinePlan: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var title: String
    public var createdAt: Date
    public var dueAt: Date
    public var targets: [DeadlineTarget]
    public init(title: String, dueAt: Date, targets: [DeadlineTarget], createdAt: Date = Date()) {
        self.title = title; self.dueAt = dueAt; self.targets = targets; self.createdAt = createdAt
    }
}

public struct DeadlineActivityForecast: Identifiable {
    public let target: DeadlineTarget
    public let recordedSeconds: Double
    public let averageSecondsPerDay: Double?
    public let projectedSeconds: Double?
    public let requiredSecondsPerDay: Double?
    public var id: UUID { target.activityID }
    public var fraction: Double { min(1, recordedSeconds / target.seconds) }
    public var isComplete: Bool { recordedSeconds + 0.001 >= target.seconds }
    public var isAtRisk: Bool { !isComplete && (projectedSeconds.map { $0 + 0.001 < target.seconds } ?? false) }
    public var projectedShortfall: Double? { projectedSeconds.map { isComplete ? 0 : max(0, target.seconds - $0) } }
}

/// An in-memory snapshot. A new snapshot is taken only at the next sampling slot
/// or when the plan changes; records arriving later do not revise the current slot.
public struct DeadlineSample: Equatable {
    public let plan: DeadlinePlan
    public let sampledAt: Date
    public let seconds: [UUID: Double]
}

public struct DeadlineForecast {
    public let activities: [DeadlineActivityForecast]
    public let remainingSeconds: Double
    public let observedSeconds: Double
    public let isExpired: Bool
    public let sample: DeadlineSample?
    public let nextSampleAt: Date?
    public var isEarlyEstimate: Bool { !isExpired && observedSeconds < 86400 }
    public var isComplete: Bool { activities.allSatisfy(\.isComplete) }
    public var atRiskCount: Int { activities.filter(\.isAtRisk).count }
    public var recordedSeconds: Double { activities.reduce(0) { $0 + $1.recordedSeconds } }
    public var targetSeconds: Double { activities.reduce(0) { $0 + $1.target.seconds } }
    public var projectedSeconds: Double? {
        guard activities.allSatisfy({ $0.projectedSeconds != nil }) else { return nil }
        return activities.reduce(0) { $0 + ($1.projectedSeconds ?? 0) }
    }
}

public enum Deadlines {
    public static let sampleInterval: TimeInterval = 15 * 60
    @discardableResult public static func create(_ j: inout Journal, title: String, dueAt: Date, targets: [DeadlineTarget], now: Date = Date()) throws -> UUID {
        let title = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard dueAt > now else { throw JournalError.invalid("Deadline phải ở tương lai.") }
        let plan = DeadlinePlan(title: title, dueAt: dueAt, targets: targets, createdAt: now)
        var draft = j; if draft.deadlines == nil { draft.deadlines = [] }; draft.deadlines?.append(plan)
        try Engine.validate(draft); j = draft; return plan.id
    }
    public static func update(_ j: inout Journal, id: UUID, title: String, dueAt: Date, targets: [DeadlineTarget], now: Date = Date()) throws {
        guard let index = j.deadlines?.firstIndex(where: { $0.id == id }), let original = j.deadlines?[index] else {
            throw JournalError.invalid("Deadline không còn tồn tại.")
        }
        guard original.dueAt > now, dueAt > now else { throw JournalError.invalid("Deadline đã đến hạn chỉ được xem. Hạn mới phải ở tương lai.") }
        var draft = j
        draft.deadlines?[index].title = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        draft.deadlines?[index].dueAt = dueAt; draft.deadlines?[index].targets = targets
        try Engine.validate(draft); j = draft
    }
    public static func delete(_ j: inout Journal, id: UUID) {
        j.deadlines?.removeAll { $0.id == id }
        if j.deadlines?.isEmpty == true { j.deadlines = nil }
    }
    public static func validate(_ j: Journal) throws {
        let plans = j.deadlines ?? []
        guard Set(plans.map(\.id)).count == plans.count else { throw JournalError.invalid("Trùng ID deadline.") }
        for plan in plans {
            guard !plan.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, plan.title.count <= 120,
                  plan.createdAt.timeIntervalSince1970.isFinite, plan.dueAt.timeIntervalSince1970.isFinite,
                  plan.dueAt > plan.createdAt, plan.dueAt.timeIntervalSince(plan.createdAt).isFinite, !plan.targets.isEmpty,
                  Set(plan.targets.map(\.activityID)).count == plan.targets.count,
                  plan.targets.allSatisfy({ j.activity($0.activityID) != nil && (1...6_000_000).contains($0.minutes) }) else {
                throw JournalError.invalid("Nhập tên deadline (tối đa 120 ký tự), hạn hợp lệ và ít nhất một hoạt động với số giờ lớn hơn 0.")
            }
        }
    }
    public static func validateChange(from original: Journal, to updated: Journal, now: Date) throws {
        for old in original.deadlines ?? [] {
            guard let changed = updated.deadlines?.first(where: { $0.id == old.id }) else { continue }
            guard changed.createdAt == old.createdAt else { throw JournalError.invalid("Không thể thay đổi thời điểm bắt đầu theo dõi deadline.") }
            guard old.dueAt > now || changed == old else { throw JournalError.invalid("Deadline đã đến hạn chỉ được xem.") }
        }
    }
    public static func forecast(_ plan: DeadlinePlan, journal: Journal, now: Date = Date(), previousSample: DeadlineSample? = nil) -> DeadlineForecast {
        let end = min(max(now, plan.createdAt), plan.dueAt)
        let observed = max(0, end.timeIntervalSince(plan.createdAt))
        let remaining = max(0, plan.dueAt.timeIntervalSince(max(now, plan.createdAt)))
        let expired = now >= plan.dueAt
        let ids = Set(plan.targets.map(\.activityID))
        func totals(through cutoff: Date) -> [UUID: Double] {
            var seconds: [UUID: Double] = [:]
            for entry in journal.entries where ids.contains(entry.activityID) {
                seconds[entry.activityID, default: 0] += overlap(entry.start, entry.end, plan.createdAt, cutoff)
            }
            return seconds
        }
        let liveSeconds = totals(through: end)
        let slots = floor(observed / sampleInterval)
        let sampleTime = expired ? plan.dueAt : plan.createdAt.addingTimeInterval(slots * sampleInterval)
        var sample: DeadlineSample?
        if expired || slots >= 1 {
            if !expired, let previousSample, previousSample.plan == plan, previousSample.sampledAt == sampleTime {
                sample = previousSample
            } else {
                sample = DeadlineSample(plan: plan, sampledAt: sampleTime,
                                        seconds: sampleTime == end ? liveSeconds : totals(through: sampleTime))
            }
        }
        let sampleObserved = sample.map { $0.sampledAt.timeIntervalSince(plan.createdAt) } ?? 0
        let sampleRemaining = sample.map { max(0, plan.dueAt.timeIntervalSince($0.sampledAt)) } ?? 0
        let activities = plan.targets.map { target in
            let actual = liveSeconds[target.activityID, default: 0]
            let sampledActual = sample?.seconds[target.activityID, default: 0] ?? 0
            let average = sampleObserved >= sampleInterval ? sampledActual / (sampleObserved / 86400) : nil
            let projection = expired ? actual : average.map { sampledActual + ($0 / 86400) * sampleRemaining }
            let required = sample != nil && sampleRemaining > 0 ? max(0, target.seconds - sampledActual) / (sampleRemaining / 86400) : nil
            return DeadlineActivityForecast(target: target, recordedSeconds: actual, averageSecondsPerDay: average, projectedSeconds: projection, requiredSecondsPerDay: required)
        }
        let nextSampleAt = expired ? nil : min(plan.dueAt, plan.createdAt.addingTimeInterval((slots + 1) * sampleInterval))
        return DeadlineForecast(activities: activities, remainingSeconds: remaining, observedSeconds: observed, isExpired: expired, sample: sample, nextSampleAt: nextSampleAt)
    }
}

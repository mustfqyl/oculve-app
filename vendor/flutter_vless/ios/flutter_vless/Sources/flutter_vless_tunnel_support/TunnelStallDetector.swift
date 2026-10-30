import Foundation

/// Notices that the Internet has "gone" for a person who is using it.
///
/// The periodic health check runs once a minute, so a dead server would leave
/// pages hanging for up to a minute. Traffic counters are free: if the device
/// keeps sending but nothing comes back, something is wrong right now, and the
/// health check can run at once instead of waiting for its turn. When nothing is
/// being sent (the phone is idle) nothing is reported, so this costs nothing.
public struct TunnelStallDetector: Equatable {
    public let window: TimeInterval
    public let minimumSentPackets: UInt64
    private var baseline: (time: Date, up: UInt64, down: UInt64)?

    public init(window: TimeInterval = 6, minimumSentPackets: UInt64 = 4) {
        self.window = window
        self.minimumSentPackets = minimumSentPackets
    }

    public static func == (lhs: TunnelStallDetector, rhs: TunnelStallDetector) -> Bool {
        lhs.window == rhs.window && lhs.minimumSentPackets == rhs.minimumSentPackets
            && lhs.baseline?.time == rhs.baseline?.time
    }

    public mutating func reset() { baseline = nil }

    /// Feeds one reading of the cumulative packet counters. Returns true once
    /// per stall: sent traffic over a full window with no answer at all.
    public mutating func record(now: Date, up: UInt64, down: UInt64) -> Bool {
        guard let start = baseline else {
            baseline = (now, up, down)
            return false
        }
        // Counters only grow. A smaller reading means the tunnel restarted.
        if up < start.up || down < start.down {
            baseline = (now, up, down)
            return false
        }
        // Anything received means the path works: start measuring again.
        if down > start.down {
            baseline = (now, up, down)
            return false
        }
        guard now.timeIntervalSince(start.time) >= window else { return false }
        let sent = up - start.up
        baseline = (now, up, down)
        return sent >= minimumSentPackets
    }
}

/// Counts consecutive failed reachability checks of the pinned server address.
public struct EndpointLiveness: Equatable {
    public let failureThreshold: Int
    public private(set) var consecutiveFailures = 0

    public init(failureThreshold: Int = 2) {
        precondition(failureThreshold > 0)
        self.failureThreshold = failureThreshold
    }

    /// Returns true when the threshold of consecutive failures is reached.
    @discardableResult
    public mutating func record(alive: Bool) -> Bool {
        if alive {
            consecutiveFailures = 0
            return false
        }
        consecutiveFailures += 1
        return consecutiveFailures >= failureThreshold
    }

    public mutating func reset() { consecutiveFailures = 0 }
}

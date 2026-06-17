// HeartBank.swift — the global HEARTS energy economy (the soft monetization lever).
//
// Hearts are your "tries" against the tough rivals. You START with a full pool and:
//   • lose 1 heart ONLY when you LOSE a match to a PREMIUM rival (never on a win,
//     never just for playing, never against the free rivals),
//   • regenerate 1 free heart every `regenMinutes` (wall-clock),
//   • can instantly refill via the $0.99 IAP, or
//   • never run out at all once "Unlock All" grants `unlimited`.
//
// Design guardrails (from the monetization research, to stay fun + Apple-safe):
//   - free rivals are ALWAYS playable even at 0 hearts → the core loop is never walled,
//   - purchased/refilled hearts must NOT decay or reset (only the free regen is timed),
//   - cost-on-loss-only + a visible free wait-path → a nudge, not a cash grab.
import SwiftUI

@MainActor
final class HeartBank: ObservableObject {
    static let maxHearts = 5
    static let regenMinutes: Double = 30

    @Published private(set) var hearts: Int = HeartBank.maxHearts
    @Published var unlimited = false          // set true by the "Unlock All" entitlement
    @Published private(set) var now = Date()  // ticked each second so the countdown updates

    private var nextRegen: Date?              // when the next +1 heart lands (nil = pool full)
    private var timer: Timer?

    private let kHearts = "fp.hearts.count"
    private let kNext = "fp.hearts.nextRegen"
    private let kSeen = "fp.hearts.lastSeen"

    init() {
        let d = UserDefaults.standard
        hearts = d.object(forKey: kHearts) == nil ? HeartBank.maxHearts : d.integer(forKey: kHearts)
        nextRegen = d.object(forKey: kNext) as? Date
        creditElapsed()
        startTimer()
    }

    var hasHeart: Bool { unlimited || hearts > 0 }

    /// Seconds until the next free heart (nil when full or unlimited).
    var secondsToNext: TimeInterval? {
        guard !unlimited, hearts < HeartBank.maxHearts, let n = nextRegen else { return nil }
        return max(0, n.timeIntervalSince(now))
    }
    var countdownString: String {
        guard let s = secondsToNext else { return "" }
        let m = Int(s) / 60, sec = Int(s) % 60
        return String(format: "%d:%02d", m, sec)
    }

    /// Spend a heart after losing a match to a premium rival.
    func spendOnLoss() {
        guard !unlimited, hearts > 0 else { return }
        hearts -= 1
        if nextRegen == nil { nextRegen = now.addingTimeInterval(HeartBank.regenMinutes * 60) }
        persist()
    }

    /// Instant full refill (the $0.99 consumable, or restored unlimited). Purchased hearts
    /// must persist and never decay, so we clear the regen timer and save immediately.
    func refillFull() {
        hearts = HeartBank.maxHearts
        nextRegen = nil
        persist()
    }

    // MARK: regen

    /// Credit any hearts earned while the app was closed (wall-clock), with a backward-
    /// clock tamper guard: if time appears to have moved backward, don't grant — just
    /// re-anchor the timer to now.
    private func creditElapsed() {
        let d = UserDefaults.standard
        let lastSeen = d.object(forKey: kSeen) as? Date
        now = Date()
        // Backward-clock guard: react ONLY to a meaningful backward jump (a manual clock
        // change / large NTP step — small slew is ignored). Preserve earned progress by
        // shifting the timer by the same delta instead of resetting the full interval,
        // and never hold a timer on a full pool ("nil = pool full").
        if let seen = lastSeen, seen.timeIntervalSince(now) > 120 {
            if hearts < HeartBank.maxHearts {
                if let n = nextRegen { nextRegen = n.addingTimeInterval(-seen.timeIntervalSince(now)) }
                else { nextRegen = now.addingTimeInterval(HeartBank.regenMinutes * 60) }
            } else {
                nextRegen = nil
            }
        }
        while hearts < HeartBank.maxHearts, let n = nextRegen, now >= n {
            hearts += 1
            nextRegen = hearts >= HeartBank.maxHearts ? nil : n.addingTimeInterval(HeartBank.regenMinutes * 60)
        }
        persist()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Cheap 1 Hz tick: just refresh `now` for the live countdown; only persist when a
    /// heart actually lands (creditElapsed does the write).
    private func tick() {
        now = Date()
        if !unlimited, hearts < HeartBank.maxHearts, let n = nextRegen, now >= n { creditElapsed() }
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(hearts, forKey: kHearts)
        d.set(nextRegen, forKey: kNext)
        d.set(now, forKey: kSeen)
    }

    #if DEBUG
    func debugSet(_ n: Int) { hearts = max(0, min(HeartBank.maxHearts, n)); if hearts < HeartBank.maxHearts && nextRegen == nil { nextRegen = now.addingTimeInterval(HeartBank.regenMinutes * 60) }; persist() }
    #endif
}

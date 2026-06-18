// PaywallView.swift — the two purchase moments:
//   • .unlock(rival): tapped a locked rival → buy that rival, or the all-access bundle.
//   • .refill: out of hearts mid-grind → buy a $0.99 refill (with a free wait-path shown).
// Both always show "Restore Purchases" (required by App Review) and never use fake
// urgency. A successful purchase continues straight into the match.
import SwiftUI

struct PaywallView: View {
    @ObservedObject var model: GameModel
    let kind: PaywallKind
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var failed = false

    private var store: Store { model.store }

    var body: some View {
        ZStack {
            ArcadeBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    closeBar
                    switch kind {
                    case .unlock(let rival): unlockBody(rival)
                    case .refill: refillBody
                    case .store: storeBody
                    }
                    Button("Restore Purchases") { run { await store.restore() } }
                        .font(.bodyBold(12)).foregroundStyle(Color(hex: "#6a6496"))
                        .padding(.top, 4)
                    if failed {
                        Text("Purchase didn't complete. Try again.")
                            .font(.body(11)).foregroundStyle(Color(hex: "#ff4d2e"))
                    }
                    Text("Payments are charged to your Apple ID. Unlocks are permanent and restore on any device.")
                        .font(.body(10)).foregroundStyle(Color(hex: "#4a4668"))
                        .multilineTextAlignment(.center).padding(.horizontal, 30).padding(.top, 2)
                }
                .padding(.horizontal, 22).padding(.bottom, 30)
            }
            if working { Color.black.opacity(0.45).ignoresSafeArea(); ProgressView().tint(.white).scaleEffect(1.4) }
        }
    }

    private var closeBar: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#a59fce")).padding(10)
                    .background(Circle().fill(Color(hex: "#14122a")))
            }
        }.padding(.top, 8)
    }

    // MARK: unlock a rival

    @ViewBuilder private func unlockBody(_ rival: Rival) -> some View {
        FaceCoin(image: rival.face, slot: .p2, size: 116).padding(.top, 4)
        Text(rival.name).font(.display(22)).foregroundStyle(Color(hex: "#ff2e88"))
            .neonGlow(Color(hex: "#ff2e88"), radius: 14).multilineTextAlignment(.center)
            .minimumScaleFactor(0.6).lineLimit(2)
        Text("LOCKED RIVAL · \(rival.difficulty.name)")
            .font(.bodyBold(11)).tracking(1.5).foregroundStyle(Color(hex: "#a59fce"))
        Text("“\(rival.taunt)”").font(.body(13)).italic()
            .foregroundStyle(Color(hex: "#8a83b8")).multilineTextAlignment(.center).padding(.horizontal, 20)

        buyButton(title: "UNLOCK \(rival.name)", price: store.displayPrice(rival.unlockProductID),
                  productID: rival.unlockProductID, kind: .cyan, sub: "Play this rival forever")

        bestValueButton

        Text("One-time purchases · no subscription")
            .font(.body(10)).foregroundStyle(Color(hex: "#4a4668")).padding(.top, 2)
    }

    // MARK: out of hearts

    @ViewBuilder private var refillBody: some View {
        Text("💔").font(.system(size: 44)).padding(.top, 4)
        Text("OUT OF HEARTS").font(.display(26)).foregroundStyle(Color(hex: "#ff2e88"))
            .neonGlow(Color(hex: "#ff2e88"), radius: 14)
        HeartsRow(remaining: model.hearts.hearts, color: Color(hex: "#ff2e88"), size: 22).padding(.vertical, 2)
        Text("You're out of tries against the tough rivals. Refill now and jump straight back in — or wait for a free heart.")
            .font(.body(13)).foregroundStyle(Color(hex: "#a59fce"))
            .multilineTextAlignment(.center).padding(.horizontal, 24)

        buyButton(title: "REFILL ALL HEARTS", price: store.displayPrice(Store.heartsRefillID),
                  productID: Store.heartsRefillID, kind: .lime, sub: "Instantly back to 5 hearts")

        if let s = model.hearts.secondsToNext {
            Text("…or wait \(fmt(s)) for your next free heart")
                .font(.body(12)).foregroundStyle(Color(hex: "#6a6496")).padding(.top, 2)
        }

        bestValueButton
    }

    // MARK: hearts & store (always reachable — tapped the heart chip)

    @ViewBuilder private var storeBody: some View {
        Image(systemName: "heart.fill").font(.system(size: 40))
            .foregroundStyle(Color(hex: "#ff2e88")).neonGlow(Color(hex: "#ff2e88"), radius: 14).padding(.top, 4)
        Text("HEARTS").font(.display(26)).foregroundStyle(Color(hex: "#ff2e88"))
            .neonGlow(Color(hex: "#ff2e88"), radius: 14)
        if model.hearts.unlimited {
            Text("∞ UNLIMITED").font(.display(20)).foregroundStyle(Color(hex: "#d4ff3d"))
                .neonGlow(Color(hex: "#d4ff3d"), radius: 10).padding(.vertical, 2)
        } else {
            HeartsRow(remaining: model.hearts.hearts, color: Color(hex: "#ff2e88"), size: 22).padding(.vertical, 2)
        }
        Text("Hearts are your tries against the premium rivals — you only lose one when you LOSE to a premium rival. The free rivals never cost a heart, and you earn a free heart every 30 minutes (up to 5).")
            .font(.body(13)).foregroundStyle(Color(hex: "#a59fce"))
            .multilineTextAlignment(.center).padding(.horizontal, 22)

        if model.hearts.unlimited {
            Text("You have the all-access bundle — unlimited hearts, forever.")
                .font(.bodyBold(12)).foregroundStyle(Color(hex: "#d4ff3d"))
                .multilineTextAlignment(.center).padding(.horizontal, 24).padding(.top, 6)
        } else {
            buyButton(title: "REFILL HEARTS", price: store.displayPrice(Store.heartsRefillID),
                      productID: Store.heartsRefillID, kind: .lime, sub: "Instantly back to 5 hearts")
            if let s = model.hearts.secondsToNext {
                Text("…or wait \(fmt(s)) for your next free heart")
                    .font(.body(12)).foregroundStyle(Color(hex: "#6a6496")).padding(.top, 2)
            }
        }

        bestValueButton
    }

    // The all-access anchor (shown on both paywalls). True 33% saving vs à-la-carte.
    @ViewBuilder private var bestValueButton: some View {
        VStack(spacing: 6) {
            Text("BEST VALUE · SAVE 33%").font(.bodyBold(10)).tracking(1.5).foregroundStyle(Color(hex: "#d4ff3d"))
            buyButton(title: "UNLOCK EVERYTHING", price: store.displayPrice(Store.allAccessID),
                      productID: Store.allAccessID, kind: .lime, sub: "All 6 rivals + unlimited hearts, forever")
        }
        .padding(.top, 8)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "#d4ff3d").opacity(0.5), lineWidth: 1.5))
    }

    private func buyButton(title: String, price: String, productID: String, kind: NeonButtonKind, sub: String) -> some View {
        Button {
            run {
                let ok = await store.buy(productID)
                await MainActor.run {
                    if ok {
                        // The proactive store stays open so the refill / unlock is visibly reflected
                        // (hearts + entitlements update reactively); the gated paywalls continue
                        // straight into the match the player was trying to start.
                        if case .store = self.kind { failed = false } else { model.proceedAfterPurchase() }
                    } else { failed = true }
                }
            }
        } label: {
            VStack(spacing: 3) {
                HStack {
                    Text(title).font(.display(15)).minimumScaleFactor(0.6).lineLimit(1)
                    Spacer()
                    Text(price).font(.display(16))
                }
                Text(sub).font(.body(10)).frame(maxWidth: .infinity, alignment: .leading).opacity(0.8)
            }
            .foregroundStyle(kind == .lime ? Color(hex: "#07070f") : Color(hex: "#07070f"))
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(kind == .lime ? Color(hex: "#d4ff3d") : Color(hex: "#19e7ff")))
            .neonGlow(kind == .lime ? Color(hex: "#d4ff3d") : Color(hex: "#19e7ff"), radius: 14)
        }
        .buttonStyle(PressDownStyle())
    }

    private func run(_ op: @escaping () async -> Void) {
        working = true; failed = false
        Task { await op(); await MainActor.run { working = false } }
    }
    private func fmt(_ s: TimeInterval) -> String {
        let m = Int(s) / 60, sec = Int(s) % 60; return String(format: "%d:%02d", m, sec)
    }
}

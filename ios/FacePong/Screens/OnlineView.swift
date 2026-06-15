// OnlineView.swift — drives an online match from authoritative server state:
// connecting → lobby → countdown → play → point → match → share. The live court
// (SpriteView) is rendered behind by RootView; this overlays the right UI.
import SwiftUI

struct OnlineView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        ZStack {
            switch model.netStatus {
            case "error": errorScreen
            case "connecting": lobby { connecting }
            case "waiting": lobby { waiting }
            default: live
            }
        }
    }

    // MARK: live

    @ViewBuilder private var live: some View {
        if model.showOnlineShare {
            ZStack { ArcadeBackground(); ShareView(model: model) }
        } else if model.netPhase == "match" {
            ZStack { ArcadeBackground(); MatchView(model: model) }
        } else if model.netPhase == "playing" {
            PlayHUD(model: model)
        } else {
            overlayCountdownOrPoint   // court shows behind
        }
    }

    @ViewBuilder private var overlayCountdownOrPoint: some View {
        if model.netPhase == "point" {
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("POINT!").font(.display(56))
                        .foregroundStyle(model.scorerIsMe ? Color(hex: "#d4ff3d") : Color(hex: "#ff2e88"))
                        .neonGlow(model.scorerIsMe ? Color(hex: "#d4ff3d") : Color(hex: "#ff2e88"), radius: 22, strong: true)
                    HStack(spacing: 10) {
                        FaceCoin(image: model.scorerIsMe ? model.p1Face : model.oppFace,
                                 slot: model.scorerIsMe ? .p1 : .p2, size: 52)
                        Text(model.scorerIsMe ? "YOU" : opp).font(.bodyBold(14)).foregroundStyle(Color(hex: "#a59fce"))
                        Text("+1").font(.display(16)).foregroundStyle(model.scorerIsMe ? Color(hex: "#19e7ff") : Color(hex: "#ff2e88"))
                    }
                    HStack(spacing: 12) {
                        FaceCoin(image: model.p1Face, slot: .p1, size: 30)
                        Text("\(model.score1) · \(model.score2)").font(.display(26)).foregroundStyle(Color(hex: "#f3f1ff"))
                        FaceCoin(image: model.oppFace, slot: .p2, size: 30)
                    }
                }
            }
            .allowsHitTesting(false)
        } else { // countdown
            VStack(spacing: 18) {
                Spacer()
                HStack(spacing: 16) {
                    VStack(spacing: 8) { FaceCoin(image: model.p1Face, slot: .p1, size: 66); Text("YOU").font(.bodyBold(14)).foregroundStyle(Color(hex: "#19e7ff")) }
                    Text("VS").font(.display(22)).foregroundStyle(Color(hex: "#d4ff3d")).rotationEffect(.degrees(-8))
                    VStack(spacing: 8) { FaceCoin(image: model.oppFace, slot: .p2, size: 66); Text(opp).font(.bodyBold(14)).foregroundStyle(Color(hex: "#ff2e88")) }
                }
                Text("\(model.serverCountdown)").font(.display(110)).foregroundStyle(.white)
                    .neonGlow(Color(hex: "#7b3bff"), radius: 30, strong: true)
                Text("GET READY").font(.display(13)).tracking(4).foregroundStyle(Color(hex: "#a59fce"))
                Spacer()
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: lobby states

    private func lobby<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ZStack { ArcadeBackground(); VStack(spacing: 14) { content() }.padding(.horizontal, 36) }
    }

    @ViewBuilder private var connecting: some View {
        ProgressView().tint(Color(hex: "#19e7ff")).scaleEffect(1.5)
        Text("Connecting…").font(.body(15)).foregroundStyle(Color(hex: "#a59fce")).padding(.top, 10)
    }

    @ViewBuilder private var waiting: some View {
        if model.isHost {
            Text("PLAY A FRIEND").font(.display(20)).foregroundStyle(Color(hex: "#d4ff3d")).neonGlow(Color(hex: "#d4ff3d"), radius: 14)
            Text("Share this code with your friend:").font(.body(14)).foregroundStyle(Color(hex: "#a59fce"))
            Text(model.hostCode).font(.display(56)).foregroundStyle(.white).tracking(4).neonGlow(Color(hex: "#7b3bff"), radius: 20, strong: true)
            ShareCodeButtons(code: model.hostCode)
        } else {
            Text("QUICK MATCH").font(.display(20)).foregroundStyle(Color(hex: "#d4ff3d")).neonGlow(Color(hex: "#d4ff3d"), radius: 14)
            ProgressView().tint(Color(hex: "#d4ff3d")).scaleEffect(1.4).padding(.vertical, 14)
            Text("Finding an opponent…").font(.body(14)).foregroundStyle(Color(hex: "#a59fce"))
        }
        NeonButton(title: "CANCEL", kind: .ghost) { model.leaveOnline() }.padding(.top, 18).padding(.horizontal, 24)
    }

    private var errorScreen: some View {
        ZStack {
            ArcadeBackground()
            VStack(spacing: 16) {
                Text("OFFLINE").font(.display(34)).foregroundStyle(Color(hex: "#ff2e88")).neonGlow(Color(hex: "#ff2e88"), radius: 16)
                Text(model.netError.isEmpty ? "Lost connection to the server." : model.netError)
                    .font(.body(14)).foregroundStyle(Color(hex: "#a59fce")).multilineTextAlignment(.center)
                NeonButton(title: "BACK", kind: .ghost) { model.leaveOnline() }.padding(.horizontal, 36).padding(.top, 8)
            }
            .padding(.horizontal, 36)
        }
    }

    private var opp: String { model.oppName.isEmpty ? "RIVAL" : model.oppName }
}

private struct ShareCodeButtons: View {
    let code: String
    @State private var showShare = false
    var body: some View {
        VStack(spacing: 12) {
            NeonButton(title: "SHARE CODE", kind: .cyan) { showShare = true }
            NeonButton(title: "COPY CODE", kind: .ghost) { UIPasteboard.general.string = code }
        }
        .padding(.horizontal, 24)
        .sheet(isPresented: $showShare) { ShareSheet(items: ["Play me in FacePong! Join code: \(code)"]) }
    }
}

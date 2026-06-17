// RootView.swift — hosts the persistent SpriteKit court and overlays the active
// SwiftUI screen. The court is visible during the countdown, play, and the
// frozen point screen; the menu/match/share screens use the arcade backdrop.
import SwiftUI
import SpriteKit

struct RootView: View {
    @StateObject private var model = GameModel()

    private var showsCourt: Bool {
        switch model.route { case .round, .play, .point, .online: return true; default: return false }
    }

    var body: some View {
        ZStack {
            if showsCourt {
                SpriteView(scene: model.scene, preferredFramesPerSecond: 120,
                           options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
            } else {
                ArcadeBackground()
            }

            switch model.route {
            case .start:  StartView(model: model)
            case .characters: CharacterSelectView(model: model)
            case .friend: FriendView(model: model)
            case .round:  RoundView(model: model)
            case .play:   PlayHUD(model: model)
            case .point:  PointView(model: model)
            case .match:  MatchView(model: model)
            case .share:  ShareView(model: model)
            case .online: OnlineView(model: model)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

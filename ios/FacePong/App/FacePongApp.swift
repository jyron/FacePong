// FacePongApp.swift — app entry. Portrait, dark, status bar hidden; the whole
// experience is a single SwiftUI tree hosting a SpriteKit game canvas.
import SwiftUI

@main
struct FacePongApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}

// FacePongApp.swift — app entry. Portrait, dark, status bar hidden; the whole
// experience is a single SwiftUI tree hosting a SpriteKit game canvas.
import SwiftUI
import PostHog

// The PostHog project token is a public client-side key — safe to ship in the
// binary. The env-var path is available for Xcode scheme overrides in local dev.
private let posthogApiKey = ProcessInfo.processInfo.environment["POSTHOG_API_KEY"]
    ?? "phc_smCbDe7P9pasHPQeDKKvJwAkYgzvLfa7mGyBwu2YUAcb"
private let posthogHost = ProcessInfo.processInfo.environment["POSTHOG_HOST"]
    ?? "https://us.i.posthog.com"

@main
struct FacePongApp: App {
    init() {
        let config = PostHogConfig(apiKey: posthogApiKey, host: posthogHost)
        config.captureApplicationLifecycleEvents = true
        PostHogSDK.shared.setup(config)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}

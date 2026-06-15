// NetConfig.swift — the Colyseus server endpoint. Production by default; override
// with the FP_SERVER env var (e.g. ws://localhost:2567) for local testing.
import Foundation

enum NetConfig {
    static let serverURL: String = {
        #if DEBUG
        if let s = ProcessInfo.processInfo.environment["FP_SERVER"], !s.isEmpty { return s }
        #endif
        return "wss://facepong-production.up.railway.app"
    }()
}

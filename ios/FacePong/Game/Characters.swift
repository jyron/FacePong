// Characters.swift — the VS COMPUTER opponent roster.
//
// Each `Rival` is a famous-personality lookalike wearing one of the Difficulty
// tiers from GameConstants. The roster is ordered EASIEST → HARDEST and maps
// 1:1 onto Difficulty.tiers, so picking a rival on the character-select screen
// IS picking a difficulty. The face is a pre-cut transparent head PNG bundled in
// Resources/Characters (char_<id>.png), produced by the same Apple-Vision cutout
// pipeline as a player selfie, so it renders as the exact same silhouette paddle.
//
// (Named `Rival`, not `Character`, to avoid shadowing Swift's stdlib Character.)
import UIKit

struct Rival: Identifiable, Equatable {
    let id: String        // asset base name → Resources/Characters/char_<id>.png
    let name: String      // shown as the opponent name in the HUD / screens
    let blurb: String     // one-line persona flavor on the select card
    let taunt: String     // short line shown on the ready screen
    let difficulty: Difficulty
    let premium: Bool     // true → must be unlocked (IAP); false → always free to play

    static func == (a: Rival, b: Rival) -> Bool { a.id == b.id }

    /// 1…N difficulty level (its position in the easiest→hardest roster).
    var level: Int { (Rival.roster.firstIndex(of: self) ?? 0) + 1 }

    /// The bundled, cached head cutout used as this rival's paddle.
    var face: UIImage? { RivalArt.shared.face(id) }

    /// StoreKit product id that unlocks this single rival.
    var unlockProductID: String { "com.facepong.unlock.\(id)" }

    // The roster. Ordered easiest → hardest; index i wears Difficulty.tiers[i].
    // The 4 easiest are FREE (a generous, genuinely-fun free tier); the 6 marquee
    // rivals are premium unlocks. Obama is the 2nd-hardest, Xi the hardest.
    static let roster: [Rival] = [
        .init(id: "singer",      name: "THE SINGER",   blurb: "Pop princess. All sparkle, no sweat.",
              taunt: "Oops… she'll do it again.",              difficulty: Difficulty.tiers[0], premium: false),
        .init(id: "king",        name: "THE KING",     blurb: "Rockabilly heartthrob with a wicked curl.",
              taunt: "Thank you. Thankyouverymuch.",           difficulty: Difficulty.tiers[1], premium: false),
        .init(id: "tycoon",      name: "THE TYCOON",   blurb: "Says his pong is tremendous. The best, really.",
              taunt: "Believe me, my rally is HUGE.",          difficulty: Difficulty.tiers[2], premium: false),
        .init(id: "founder",     name: "THE FOUNDER",  blurb: "Ships paddles to Mars. Sleeps at the factory.",
              taunt: "This rally is going multi-planetary.",   difficulty: Difficulty.tiers[3], premium: false),
        .init(id: "interesting", name: "THE MOST INTERESTING MAN", blurb: "Doesn't always play pong. But when he does…",
              taunt: "Stay rallying, my friend.",              difficulty: Difficulty.tiers[4], premium: true),
        .init(id: "wrestler",    name: "THE WRESTLER", blurb: "24-inch pythons and a yellow bandana.",
              taunt: "Whatcha gonna do, brother?!",            difficulty: Difficulty.tiers[5], premium: true),
        .init(id: "champ",       name: "THE CHAMP",    blurb: "Heavyweight. Everybody has a plan until…",
              taunt: "I'm gonna rally you into oblivion.",     difficulty: Difficulty.tiers[6], premium: true),
        .init(id: "dictator",    name: "THE DICTATOR", blurb: "Cold. Ruthless. Never misses.",
              taunt: "You will not score. This is decided.",   difficulty: Difficulty.tiers[7], premium: true),
        .init(id: "president",   name: "THE PRESIDENT", blurb: "Cool, composed, devastating cross-court.",
              taunt: "Let me be clear — you're going to lose.", difficulty: Difficulty.tiers[8], premium: true),
        .init(id: "chairman",    name: "THE CHAIRMAN", blurb: "Supreme leader of the court. Absolute control.",
              taunt: "There is no opposition. Only the State.", difficulty: Difficulty.tiers[9], premium: true),
    ]

    /// The default rival when none is chosen (rematch / dev launch paths).
    static let `default` = roster[8]   // THE PRESIDENT (a real fight, not a wall)
}

/// What the paywall sheet is currently selling.
enum PaywallKind: Identifiable {
    case unlock(Rival)   // tapped a locked rival
    case refill          // out of hearts, wants to keep trying
    var id: String {
        switch self {
        case .unlock(let r): return "unlock-\(r.id)"
        case .refill: return "refill"
        }
    }
}

/// Loads + caches the bundled rival head cutouts once.
final class RivalArt {
    static let shared = RivalArt()
    private var cache: [String: UIImage] = [:]

    func face(_ id: String) -> UIImage? {
        if let c = cache[id] { return c }
        guard let url = Bundle.main.url(forResource: "char_\(id)", withExtension: "png"),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        cache[id] = img
        return img
    }
}

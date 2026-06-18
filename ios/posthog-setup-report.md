<wizard-report>
# PostHog post-wizard report

The wizard has completed a full PostHog analytics integration for FacePong iOS. The posthog-ios SDK (v3.61.0) was added to the Xcode project via Swift Package Manager, initialized at app launch in `FacePongApp.swift`, and 11 business-critical events were instrumented across 5 source files — covering the match lifecycle, IAP/paywall funnel, heart economy, rival progression, and online play.

| Event | Description | File |
|---|---|---|
| `match_started` | Player starts a CPU match after passing all monetization gates | `FacePong/App/GameModel.swift` |
| `match_completed` | Match ends with outcome, rival, score, rally, aces, duration | `FacePong/App/GameModel.swift` |
| `rival_conquered` | Player defeats a rival for the first time | `FacePong/App/GameModel.swift` |
| `rival_selected` | Player taps a rival card on the character select screen | `FacePong/App/GameModel.swift` |
| `face_set` | Player successfully sets their selfie as the paddle (first time) | `FacePong/App/GameModel.swift` |
| `store_opened` | Player opens the proactive hearts/store sheet | `FacePong/App/GameModel.swift` |
| `online_match_started` | Player initiates an online match (quick/friend_host/friend_join) | `FacePong/App/GameModel.swift` |
| `paywall_viewed` | A paywall sheet is presented (unlock/refill/store, with rival context) | `FacePong/Screens/PaywallView.swift` |
| `purchase_completed` | An IAP was successfully processed | `FacePong/Game/Store.swift` |
| `purchase_failed` | An IAP attempt was cancelled or failed | `FacePong/Game/Store.swift` |
| `heart_spent` | Player loses a heart after being defeated by a premium rival | `FacePong/Game/HeartBank.swift` |

## Next steps

A dashboard and 5 insights were created in PostHog:

- [Analytics basics (wizard) — Dashboard](https://us.posthog.com/project/466052/dashboard/1731868)
- [Matches Started (Daily)](https://us.posthog.com/project/466052/insights/sFsJTAbF)
- [Win / Loss Rate](https://us.posthog.com/project/466052/insights/z94QLKFS)
- [IAP Conversion Funnel](https://us.posthog.com/project/466052/insights/kA4dOOlN)
- [Hearts Spent (Daily)](https://us.posthog.com/project/466052/insights/i2K3JcST)
- [Rivals Conquered (Daily)](https://us.posthog.com/project/466052/insights/VtDYCtKJ)

## Verify before merging

- [ ] Run a full production build (the wizard only verified the files it touched) and fix any lint or type errors introduced by the generated code.
- [ ] Run the test suite — call sites that were rewritten or instrumented may need updated mocks or fixtures.
- [ ] Add `POSTHOG_API_KEY` and `POSTHOG_HOST` to any `.env.example` or bootstrap scripts so collaborators know what to set for Xcode scheme overrides.

### Agent skill

We've left an agent skill folder in your project. You can use this context for further agent development when using Claude Code. This will help ensure the model provides the most up-to-date approaches for integrating PostHog.

</wizard-report>

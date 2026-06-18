# FacePong 🏓

A retro-arcade neon ping-pong game where **your face is the paddle**. Three modes:

- **Vs Computer** — fully offline single-player against an AI paddle.
- **Quick Match** — get randomly paired with another waiting player online.
- **Play a Friend** — create a private game and share the code, or join by code.

The native iOS app plays live online matches through one hosted authoritative
game server.

## Structure

```
facepong/
  ios/         Native iPhone app — Swift + SpriteKit + SwiftUI + Apple Vision.
               The shipping app (App Store: com.facepong.app).
    FacePong/
      Game/      SpriteKit court, comet trail, ball, FacePaddleNode (warp deform),
                 deterministic PongEngine (Swift port of server/src/engine.ts)
      Vision/    FaceCutout (VNGenerateForegroundInstanceMask + face-box head crop
                 + edge feather) and the camera/photo picker
      Net/       Native Colyseus 0.16 client (matchmaking + WebSocket + schema-v3
                 decode + msgpack) — speaks the server's Colyseus protocol
      Screens/   Start, Friend, Round, PlayHUD, Point, Match, Share, Online (SwiftUI)
      UI/Theme/  Neon design system, palette, fonts
    project.yml  xcodegen project spec    tools/sim.sh  build+run+screenshot helper

  server/      Colyseus authoritative game server (Node + TypeScript).
    src/engine.ts            ball physics + collisions + scoring (the iOS engine is
                             a verbatim Swift port of this); constants.ts is geometry
    src/rooms/PongRoom.ts    60Hz authoritative physics, scoring, matchmaking
    src/schema/PongState.ts  synced room state (incl. each player's face cutout)

  appstore/    Marketing & store assets — promo video, screenshot sets, generators.
```

The iOS client and the server share one physics engine (`server/src/engine.ts`,
ported to Swift on the client), so offline "Vs Computer" and online matches behave
identically.

## Running it

**iOS (native):**
```bash
cd ios
brew install xcodegen                 # one-time
tools/sim.sh                          # build, install, run on a booted simulator
# or open FacePong.xcodeproj in Xcode and run on a device
```
Apple Vision's foreground-mask request only runs on real hardware, not the
simulator — test the camera→cutout flow on a device or via `tools/facecutout.swift`
on the Mac.

**Server:**
```bash
cd server
npm run dev                           # ws://localhost:2567
```
Point the iOS client at a local server with `FP_SERVER=ws://localhost:2567` (DEBUG).

## Deployment

- **Server:** Railway auto-deploys on push to `main` (`railway.json` → builds `server/`).
  Endpoint: **wss://facepong-production.up.railway.app**.
- **iOS:** `xcodebuild archive` + `exportArchive` (upload) to App Store Connect app
  `6779310642` using the ASC API key. Build number must exceed the last upload.

## How the netcode works

- The server runs the **same physics engine** (`server/src/engine.ts`)
  authoritatively at 60Hz and patches state to clients at 60Hz.
- Canonical frame is p1=bottom; a p2 client **flips Y** so each player sees
  themselves at the bottom (cyan), opponent at top (magenta).
- The local paddle is **client-predicted** from finger input; the ball and opponent
  paddle are **interpolated** toward server snapshots.
- Each player's segmented face cutout rides in room **state** (`Player.faceData`),
  so it syncs to the opponent — including a late joiner — automatically.

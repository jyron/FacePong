# FacePong 🏓

A retro-arcade neon ping-pong game where **your face is the paddle**. Built from a
Claude Design handoff. Cross-platform (iOS + Android) via Expo, with three modes:

- **Vs Computer** — fully offline single-player against an AI paddle.
- **Quick Match** — get randomly paired with another waiting player online.
- **Play a Friend** — create a private game and share the code, or join by code.

Two people on two different devices (iPhone ↔ Android) play the same live match
through a hosted authoritative game server.

## Structure

```
facepong/
  client/            Expo (React Native + TypeScript) app — the game
    shared/          SINGLE SOURCE OF TRUTH: physics engine, geometry constants,
                     network protocol. Imported by the client AND bundled into
                     the server, so the two can never disagree.
    src/
      game/          Skia court + physics loop (usePongEngine) for CPU play
      net/           Colyseus client + networked renderer (useNetGame)
      screens/       Start, Friend menu, Round, Play, Point, Match, Share, OnlineGame
      components/    FaceCoin, NeonButton, ScoreChip, Confetti, ArcadeBg
      faces/         photo/selfie picker + face store (AsyncStorage)
      theme/         neon-arcade tokens ported from the design
    shims/ws.js      makes colyseus.js use RN's global WebSocket
  server/            Colyseus authoritative game server (Node + TypeScript)
    src/rooms/PongRoom.ts   60Hz authoritative physics, scoring, matchmaking
    src/schema/PongState.ts synced room state
```

## Running it

**Client (the game):**
```bash
cd client
npx expo start          # then press i (iOS sim) / a (Android), or scan the QR in Expo Go
```
Everything runs in **Expo Go** — no native build needed for development. The whole
dependency set (Skia, Reanimated, gesture-handler, camera, etc.) is bundled in Expo Go.

**Server:** already deployed to Railway (see below). To run it locally instead, set
`client/src/net/config.ts` `SERVER_URL` to `ws://localhost:2567` and:
```bash
cd server
npm run dev
```

## Deployment (Railway)

The realtime server is deployed to Railway (project **facepong**) at:

- **wss://facepong-production.up.railway.app** (used by `client/src/net/config.ts`)

To redeploy after server changes:
```bash
cd server
npm run build          # tsup bundles src + client/shared into dist/index.js
railway up             # uploads & deploys (uses railway.json: prebuilt dist, no rebuild)
```

## How the netcode works

- The server runs the **same physics engine** (`client/shared/engine.ts`) the client
  uses for CPU play, authoritatively at 60Hz, and patches state to clients ~20Hz.
- Canonical frame is p1=bottom; a p2 client **flips Y** so each player sees themselves
  at the bottom (cyan), opponent at top (magenta).
- The local paddle is **client-predicted** from finger input; the ball and opponent
  paddle are **interpolated** toward server snapshots. All position writes happen on the
  UI thread (Reanimated `useFrameCallback` / `runOnUI`) so Skia animates smoothly.
- Faces are sent once per player (~256px JPEG) and relayed to the opponent.

## Status / notes

**Verified** (two iOS simulators against the live Railway server):
- Vs Computer — full game with real finger-drag paddle control, scoring, all screens.
- Quick Match — random pairing, synchronized match, mirrored scores, full flow.
- Play a Friend — host gets a code (e.g. `E4FS`), friend joins by code, they pair.
- Faces — a chosen image renders on your paddle and transmits to the opponent's screen.

**Known gaps / not yet done:**
- **Android untested here** (no Android emulator on this machine). It runs the same JS
  client and talks to the same server/protocol, so it's expected to interoperate — confirm
  on a real Android device or an EAS build.
- **Photo-picker UI** wasn't automatable in this environment, so the in-app pick/selfie
  flow (standard `expo-image-picker`) is built but its UI is unverified; the
  send→relay→render half was verified with a seeded image.
- **Opponent leaves mid-match:** the remaining player drops to a waiting/"OFFLINE" state
  with no explicit "opponent left" message — functional but unpolished.
- **App Store / Play Store release** is a separate step (EAS Build + Apple Developer
  $99/yr + Google Play $25). Development/testing needs none of that.

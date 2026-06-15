// Anonymous product analytics via PostHog (free tier: 1M events/month).
// No login required — PostHog persists a random anonymous distinct ID on the
// device, which is what makes DAU/MAU/retention numbers possible.
//
// The project API key is a PUBLIC client-side key (like any mobile analytics
// key) — it can only ingest events, not read data, so committing it is fine.
// Paste yours into client/.env (EXPO_PUBLIC_POSTHOG_API_KEY=phc_...), from
// PostHog → Settings → Project → Project API key.
// With no key set, every call below is a silent no-op (e.g. local dev).
import PostHog from 'posthog-react-native';

const POSTHOG_API_KEY = process.env.EXPO_PUBLIC_POSTHOG_API_KEY ?? '';
const POSTHOG_HOST = 'https://us.i.posthog.com';

export const posthog = POSTHOG_API_KEY
  ? new PostHog(POSTHOG_API_KEY, {
      host: POSTHOG_HOST,
      // "Application Installed / Opened / Became Active / Backgrounded" —
      // these power the user/session counts without any manual calls.
      captureAppLifecycleEvents: true,
    })
  : null;

export type GameMode = 'cpu' | 'quick' | 'friend-create' | 'friend-join';

export const track = {
  gameStarted: (mode: GameMode) => posthog?.capture('game_started', { mode }),
  gameFinished: (p: {
    mode: GameMode;
    won: boolean;
    myScore: number;
    oppScore: number;
    topRally: number;
    durationS: number;
  }) =>
    posthog?.capture('game_finished', {
      mode: p.mode,
      won: p.won,
      my_score: p.myScore,
      opp_score: p.oppScore,
      top_rally: p.topRally,
      duration_s: p.durationS,
    }),
  gameQuit: (mode: GameMode) => posthog?.capture('game_quit', { mode }),
  onlineMatchFound: (mode: GameMode) => posthog?.capture('online_match_found', { mode }),
  friendCodeShared: () => posthog?.capture('friend_code_shared'),
  faceSelected: (source: 'camera' | 'library') => posthog?.capture('face_selected', { source }),
  resultShared: () => posthog?.capture('result_shared'),
};

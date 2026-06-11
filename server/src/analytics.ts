// Server-side PostHog capture for authoritative online-match counts. Client
// events are per-player (two players in one match each send game_finished);
// these server events count each online match exactly once.
// Configure POSTHOG_API_KEY on Railway (same project key as the client). With
// no key set, track() is a silent no-op.
import { PostHog } from 'posthog-node';

const key = process.env.POSTHOG_API_KEY;

const posthog = key
  ? new PostHog(key, {
      host: process.env.POSTHOG_HOST || 'https://us.i.posthog.com',
      // Event volume is tiny (a handful per match) — send immediately rather
      // than holding a 20-event batch that may never fill.
      flushAt: 1,
    })
  : null;

// All server events share one distinct ID so they never inflate user counts —
// users are counted from the anonymous client-side IDs.
export function track(event: string, properties?: Record<string, unknown>) {
  posthog?.capture({ distinctId: 'facepong-server', event, properties });
}

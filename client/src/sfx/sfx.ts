// All game sound + haptics behind one tiny API. Players are created once at
// module load (createAudioPlayer — manual lifecycle, they live for the app's
// lifetime) and replayed with seekTo(0), which is how expo-audio does
// rapid-fire SFX. Every call is fire-and-forget and swallows errors so a
// missing native module (e.g. Expo Go) silently mutes the game instead of
// crashing it.
//
// Escalation is the addictive bit: the paddle blip's playbackRate climbs with
// the rally, so long rallies audibly wind up like a coin pusher.
import { createAudioPlayer, setAudioModeAsync, type AudioPlayer } from 'expo-audio';
import * as Haptics from 'expo-haptics';

const make = (src: number): AudioPlayer | null => {
  try {
    return createAudioPlayer(src);
  } catch {
    return null;
  }
};

const players = {
  // Two paddle players round-robined so your hit and the CPU's return don't
  // cut each other off mid-blip during fast rallies.
  paddle: [make(require('../../assets/sfx/paddle.wav')), make(require('../../assets/sfx/paddle.wav'))],
  wall: make(require('../../assets/sfx/wall.wav')),
  score: make(require('../../assets/sfx/score.wav')),
  lose: make(require('../../assets/sfx/lose.wav')),
  milestone: make(require('../../assets/sfx/milestone.wav')),
  tick: make(require('../../assets/sfx/tick.wav')),
  fanfare: make(require('../../assets/sfx/fanfare.wav')),
};
let paddleIdx = 0;

function replay(p: AudioPlayer | null, rate = 1, volume = 1) {
  if (!p) return;
  try {
    p.volume = volume;
    p.setPlaybackRate(rate);
    p.seekTo(0);
    p.play();
  } catch {
    // muted (no native audio) — gameplay continues silently
  }
}

const haptic = (fn: () => Promise<void>) => fn().catch(() => {});

// Call once at app start. A game must beep even with the iOS mute switch on.
export function initSfx(): void {
  setAudioModeAsync({ playsInSilentMode: true }).catch(() => {});
}

export const sfx = {
  // Paddle hit. Pitch climbs with the rally (capped) and the opponent's hits
  // sit lower so the two sides of a rally are distinguishable by ear; yours
  // also thump in your hand.
  paddle(slot: 'p1' | 'p2', rally: number): void {
    const rate = Math.min(1 + rally * 0.035, 1.7) * (slot === 'p1' ? 1 : 0.82);
    replay(players.paddle[paddleIdx], rate);
    paddleIdx = (paddleIdx + 1) % players.paddle.length;
    haptic(() =>
      Haptics.impactAsync(
        slot === 'p1' ? Haptics.ImpactFeedbackStyle.Medium : Haptics.ImpactFeedbackStyle.Light,
      ),
    );
  },

  wall(): void {
    replay(players.wall, 0.9 + Math.random() * 0.25, 0.7);
  },

  point(won: boolean): void {
    replay(won ? players.score : players.lose);
    haptic(() =>
      Haptics.notificationAsync(
        won ? Haptics.NotificationFeedbackType.Success : Haptics.NotificationFeedbackType.Error,
      ),
    );
  },

  milestone(): void {
    replay(players.milestone);
    haptic(() => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy));
  },

  // Countdown tick; `go` is the same blip a fifth up.
  tick(go = false): void {
    replay(players.tick, go ? 1.5 : 1);
    haptic(() => Haptics.selectionAsync());
  },

  fanfare(): void {
    replay(players.fanfare);
    haptic(() => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success));
  },
};

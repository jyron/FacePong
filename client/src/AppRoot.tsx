// Top-level game flow / state machine. Owns the shared pong engine and routes
// between the six screens. This build wires "Vs Computer" end-to-end; the
// online modes (quick / friend) are added on top in the networking step.
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import { usePongEngine } from './game/usePongEngine';
import { StartScreen } from './screens/StartScreen';
import { RoundScreen } from './screens/RoundScreen';
import { PlayScreen } from './screens/PlayScreen';
import { PointScreen } from './screens/PointScreen';
import { MatchScreen } from './screens/MatchScreen';
import { ShareScreen } from './screens/ShareScreen';
import { FriendMenu } from './screens/FriendMenu';
import { OnlineGame, type OnlineMode } from './screens/OnlineGame';
import { initSfx } from './sfx/sfx';
import { C } from './theme/tokens';
import { TARGET_SCORE, type Slot } from '../shared/constants';
import type { Mode } from '../shared/protocol';

type Route = 'start' | 'friend' | 'round' | 'play' | 'point' | 'match' | 'share';
type Scores = { p1: number; p2: number };

const CPU_NAME = 'CPU';
const randomCode = () => Math.random().toString(36).slice(2, 6).toUpperCase();

export function AppRoot() {
  const [route, setRoute] = useState<Route>('start');
  const [opponent, setOpponent] = useState(CPU_NAME);
  const [scores, setScores] = useState<Scores>({ p1: 0, p2: 0 });
  const [lastScorer, setLastScorer] = useState<Slot>('p1');
  const [matchOver, setMatchOver] = useState(false);
  const [best, setBest] = useState(0);
  const [code] = useState(randomCode);
  const [online, setOnline] = useState<{ mode: OnlineMode; code?: string } | null>(null);
  const [rally, setRally] = useState(0);

  const scoresRef = useRef<Scores>({ p1: 0, p2: 0 });
  const statsRef = useRef({ topRally: 0, aces: 0 });
  const startedAt = useRef(Date.now());

  useEffect(() => initSfx(), []);

  // Engine score callback — fires when a point ends.
  const onScore = useCallback((slot: Slot) => {
    const rally = engine.getRally();
    statsRef.current.topRally = Math.max(statsRef.current.topRally, rally);
    if (rally === 0) statsRef.current.aces += 1;
    setBest((b) => Math.max(b, rally));

    const next: Scores = { ...scoresRef.current, [slot]: scoresRef.current[slot] + 1 };
    scoresRef.current = next;
    setScores(next);
    setLastScorer(slot);
    setMatchOver(next[slot] >= TARGET_SCORE);

    engine.freezePose();
    setRoute('point');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const engine = usePongEngine(onScore);

  // poll the live rally count for the HUD while playing the CPU
  useEffect(() => {
    if (route !== 'play') return;
    const id = setInterval(() => setRally(engine.getRally()), 120);
    return () => clearInterval(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [route]);

  const resetMatch = () => {
    scoresRef.current = { p1: 0, p2: 0 };
    statsRef.current = { topRally: 0, aces: 0 };
    startedAt.current = Date.now();
    setScores({ p1: 0, p2: 0 });
    setMatchOver(false);
  };

  const startCpuMatch = () => {
    resetMatch();
    setOpponent(CPU_NAME);
    setRoute('round');
  };

  const beginRally = (serveToward: Slot) => {
    engine.startCpu(serveToward);
    setRoute('play');
  };

  const winnerSlot: Slot = scoresRef.current.p1 >= scoresRef.current.p2 ? 'p1' : 'p2';
  const winnerName = winnerSlot === 'p1' ? 'YOU' : opponent;
  const timeStr = () => {
    const s = Math.floor((Date.now() - startedAt.current) / 1000);
    return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  };

  const onMode = (m: Mode) => {
    if (m === 'cpu') startCpuMatch();
    else if (m === 'quick') setOnline({ mode: 'quick' });
    else setRoute('friend');
  };

  const round = scoresRef.current.p1 + scoresRef.current.p2 + 1;

  if (online) {
    return (
      <View style={styles.root}>
        <OnlineGame
          mode={online.mode}
          code={online.code}
          playerName="RIVAL"
          onExit={() => {
            setOnline(null);
            setRoute('start');
          }}
        />
      </View>
    );
  }

  return (
    <View style={styles.root}>
      {route === 'start' && <StartScreen best={best} onMode={onMode} />}

      {route === 'friend' && (
        <FriendMenu
          onBack={() => setRoute('start')}
          onCreate={() => setOnline({ mode: 'friend-create' })}
          onJoin={(c) => setOnline({ mode: 'friend-join', code: c })}
        />
      )}

      {route === 'round' && (
        <RoundScreen round={1} opponentName={opponent} onDone={() => beginRally('p1')} />
      )}

      {route === 'play' && (
        <PlayScreen
          engine={engine}
          scores={scores}
          round={round}
          rally={rally}
          opponentName={opponent}
          onQuit={() => {
            engine.stop();
            setRoute('start');
          }}
        />
      )}

      {route === 'point' && (
        <PointScreen
          engine={engine}
          scorer={lastScorer}
          scorerName={lastScorer === 'p1' ? 'YOU' : opponent}
          scores={scores}
          matchPointNext={
            !matchOver &&
            (scoresRef.current.p1 === TARGET_SCORE - 1 || scoresRef.current.p2 === TARGET_SCORE - 1)
          }
          autoNextMs={2600}
          onNext={() => {
            if (matchOver) setRoute('match');
            else beginRally(lastScorer === 'p1' ? 'p2' : 'p1');
          }}
          onSkipToMatch={() => {
            scoresRef.current = { p1: Math.max(scoresRef.current.p1, TARGET_SCORE), p2: scoresRef.current.p2 };
            setScores({ ...scoresRef.current });
            setMatchOver(true);
            setRoute('match');
          }}
        />
      )}

      {route === 'match' && (
        <MatchScreen
          winner={winnerSlot}
          winnerName={winnerName}
          scores={scores}
          stats={{ topRally: statsRef.current.topRally, aces: statsRef.current.aces, time: timeStr() }}
          onShare={() => setRoute('share')}
          onRematch={startCpuMatch}
          onHome={() => {
            engine.stop();
            setRoute('start');
          }}
        />
      )}

      {route === 'share' && (
        <ShareScreen
          winner={winnerSlot}
          winnerName={winnerName}
          scores={scores}
          code={code}
          onDone={() => setRoute('start')}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({ root: { flex: 1, backgroundColor: C.bg } });

// Drives an online match: connect -> lobby -> countdown -> play -> point ->
// match -> share, all from authoritative server state via useNetGame. Reuses
// PlayScreen / MatchScreen / ShareScreen; renders lightweight overlays for the
// connect / wait / countdown / point phases.
import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  Share,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import * as Clipboard from 'expo-clipboard';
import { PongCourt } from '../game/PongCourt';
import { FaceCoin } from '../components/FaceCoin';
import { ScoreChip } from '../components/ScoreChip';
import { NeonButton } from '../components/NeonButton';
import { ArcadeBg } from '../components/ArcadeBg';
import { PlayScreen } from './PlayScreen';
import { MatchScreen } from './MatchScreen';
import { ShareScreen } from './ShareScreen';
import { useFaces } from '../faces/FaceStore';
import { useNetGame } from '../net/useNetGame';
import { joinQuick, createFriend, joinFriend, makeFriendCode } from '../net/client';
import { C, FONT } from '../theme/tokens';
import { sfx } from '../sfx/sfx';
import { track } from '../analytics';
import { COURT, type Slot } from '../../shared/constants';

export type OnlineMode = 'quick' | 'friend-create' | 'friend-join';

export function OnlineGame({
  mode,
  code,
  playerName,
  onExit,
}: {
  mode: OnlineMode;
  code?: string;
  playerName: string;
  onExit: () => void;
}) {
  const { faces } = useFaces();
  const { width, height } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const scale = Math.min(width / COURT.W, height / COURT.H);
  const startedAt = useRef(Date.now());
  const friendCode = useRef(makeFriendCode());
  const [showShare, setShowShare] = useState(false);
  // The opponent's real face, received over the network. Kept LOCAL to this
  // match — never written into the persistent FaceStore, whose p2 slot is the
  // face the user picked for offline/CPU play. Until it arrives (or if the
  // opponent never set one) we show the default avatar, not the local p2 pick.
  const [oppFace, setOppFace] = useState<string | null>(null);

  const connect = useMemo(() => {
    if (mode === 'friend-create') return () => createFriend(friendCode.current, playerName);
    if (mode === 'friend-join') return () => joinFriend((code || '').trim(), playerName);
    return () => joinQuick(playerName);
  }, [mode, code, playerName]);

  const net = useNetGame({
    connect,
    myFaceDataUri: faces.p1,
    onOppFace: setOppFace,
  });

  const matchFaces = useMemo(() => ({ p1: faces.p1, p2: oppFace }), [faces.p1, oppFace]);

  // Analytics: one game_started per online session, one online_match_found per
  // opponent pairing, one game_finished per completed match. Refs guard against
  // re-fires when status flaps (e.g. opponent leaves -> back to waiting).
  const trackedFound = useRef(false);
  const trackedFinish = useRef(false);
  useEffect(() => {
    track.gameStarted(mode);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  useEffect(() => {
    if (net.status === 'live' && !trackedFound.current) {
      trackedFound.current = true;
      track.onlineMatchFound(mode);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [net.status]);
  useEffect(() => {
    if (net.phase === 'match' && !trackedFinish.current) {
      trackedFinish.current = true;
      track.gameFinished({
        mode,
        won: (net.winnerSlot || (net.scores.p1 >= net.scores.p2 ? 'p1' : 'p2')) === 'p1',
        myScore: net.scores.p1,
        oppScore: net.scores.p2,
        topRally: net.topRally,
        durationS: Math.floor((Date.now() - startedAt.current) / 1000),
      });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [net.phase]);

  // Audio cues for the server-driven phases (the local overlays below don't
  // mount/unmount per number, so tick on countdown changes and beep on points).
  useEffect(() => {
    if (net.phase === 'countdown' && net.countdown > 0) sfx.tick();
  }, [net.phase, net.countdown]);
  useEffect(() => {
    if (net.phase === 'point' && net.scorerSlot) sfx.point(net.scorerSlot === 'p1');
  }, [net.phase, net.scorerSlot]);

  const timeStr = () => {
    const s = Math.floor((Date.now() - startedAt.current) / 1000);
    return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  };
  const winner: Slot = net.winnerSlot || (net.scores.p1 >= net.scores.p2 ? 'p1' : 'p2');
  const winnerName = winner === 'p1' ? 'YOU' : net.oppName || 'OPPONENT';
  const oppName = net.oppName || 'RIVAL';

  // ---- connection / lobby states ----
  if (net.status === 'error') {
    return (
      <Centered>
        <Text style={styles.big}>OFFLINE</Text>
        <Text style={styles.sub}>{net.error || 'Lost connection to the server.'}</Text>
        <View style={styles.lobbyBtns}>
          <NeonButton label="BACK" variant="ghost" onPress={onExit} />
        </View>
      </Centered>
    );
  }

  if (net.status === 'connecting') {
    return (
      <Centered>
        <ActivityIndicator color={C.cyan} size="large" />
        <Text style={[styles.sub, { marginTop: 18 }]}>Connecting…</Text>
      </Centered>
    );
  }

  if (net.status === 'waiting') {
    const isHost = mode === 'friend-create';
    const hostCode = net.code || friendCode.current;
    return (
      <Centered>
        <Text style={styles.kicker}>{isHost ? 'PLAY A FRIEND' : 'QUICK MATCH'}</Text>
        {isHost ? (
          <>
            <Text style={styles.sub}>Share this code with your friend:</Text>
            <Text style={styles.code}>{hostCode}</Text>
            <View style={styles.lobbyBtns}>
              <NeonButton
                label="SHARE CODE"
                variant="cyan"
                onPress={() => {
                  track.friendCodeShared();
                  Share.share({ message: `Play me in FacePong! Join code: ${hostCode}` }).catch(() => {});
                }}
              />
              <NeonButton label="COPY CODE" variant="ghost" small onPress={() => Clipboard.setStringAsync(hostCode)} />
            </View>
          </>
        ) : (
          <>
            <ActivityIndicator color={C.lime} size="large" style={{ marginVertical: 18 }} />
            <Text style={styles.sub}>Finding an opponent…</Text>
          </>
        )}
        <View style={[styles.lobbyBtns, { marginTop: 26 }]}>
          <NeonButton label="CANCEL" variant="ghost" small onPress={onExit} />
        </View>
      </Centered>
    );
  }

  // ---- live match ----
  if (showShare) {
    return (
      <ShareScreen
        winner={winner}
        winnerName={winnerName}
        scores={net.scores}
        code={net.code || 'PLAY'}
        onDone={onExit}
      />
    );
  }

  if (net.phase === 'match') {
    return (
      <MatchScreen
        winner={winner}
        winnerName={winnerName}
        scores={net.scores}
        stats={{ topRally: net.topRally, aces: 0, time: timeStr() }}
        onShare={() => setShowShare(true)}
        onRematch={onExit}
        onHome={onExit}
      />
    );
  }

  if (net.phase === 'playing') {
    return (
      <PlayScreen
        engine={net.visual}
        faces={matchFaces}
        scores={net.scores}
        round={net.round}
        rally={net.rally}
        opponentName={oppName}
        onQuit={() => {
          track.gameQuit(mode);
          net.leave();
          onExit();
        }}
      />
    );
  }

  // countdown or point — court backdrop + overlay
  const courtW = COURT.W * scale;
  const courtH = COURT.H * scale;
  const scorer = net.scorerSlot || 'p1';
  return (
    <View style={styles.liveRoot}>
      {/* interactive: players can position their paddle during the countdown */}
      <View style={{ width: courtW, height: courtH, overflow: 'hidden' }}>
        <PongCourt engine={net.visual} faces={matchFaces} scale={scale} interactive />
      </View>

      {net.phase === 'countdown' ? (
        <View style={styles.overlay} pointerEvents="none">
          <View style={styles.vs}>
            <View style={styles.who}>
              <FaceCoin slot="p1" size={66} uri={matchFaces.p1} />
              <Text style={[styles.name, { color: C.cyan }]}>YOU</Text>
            </View>
            <Text style={styles.vsBadge}>VS</Text>
            <View style={styles.who}>
              <FaceCoin slot="p2" size={66} uri={matchFaces.p2} />
              <Text style={[styles.name, { color: C.magenta }]}>{oppName}</Text>
            </View>
          </View>
          <Text style={styles.count}>{net.countdown}</Text>
          <Text style={styles.ready}>GET READY</Text>
        </View>
      ) : (
        <View style={[styles.overlay, { backgroundColor: 'rgba(7,7,15,0.6)' }]} pointerEvents="none">
          <Text style={styles.point}>POINT!</Text>
          <View style={styles.pointBy}>
            <FaceCoin slot={scorer} size={52} uri={matchFaces[scorer]} />
            <Text style={[styles.name, { color: scorer === 'p1' ? C.cyan : C.magenta }]}>
              {scorer === 'p1' ? 'YOU' : oppName}
            </Text>
            <Text style={styles.delta}>+1</Text>
          </View>
          <View style={{ marginTop: 20 }}>
            <ScoreChip p1={net.scores.p1} p2={net.scores.p2} size={34} />
          </View>
        </View>
      )}
    </View>
  );
}

function Centered({ children }: { children: React.ReactNode }) {
  const { width, height } = useWindowDimensions();
  return (
    <View style={styles.centered}>
      <ArcadeBg width={width} height={height} />
      <View style={styles.centeredInner}>{children}</View>
    </View>
  );
}

const styles = StyleSheet.create({
  centered: { flex: 1, backgroundColor: C.bg },
  centeredInner: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 36 },
  big: { fontFamily: FONT.display, fontSize: 34, color: C.magenta, textShadowColor: 'rgba(255,46,136,0.5)', textShadowRadius: 18, textShadowOffset: { width: 0, height: 0 } },
  kicker: { fontFamily: FONT.display, fontSize: 16, letterSpacing: 3, color: C.lime, marginBottom: 18 },
  sub: { fontFamily: FONT.body, color: C.inkDim, fontSize: 14, textAlign: 'center', marginTop: 8 },
  code: { fontFamily: FONT.display, fontSize: 44, color: C.ink, letterSpacing: 4, marginVertical: 18, textShadowColor: 'rgba(123,59,255,0.6)', textShadowRadius: 22, textShadowOffset: { width: 0, height: 0 } },
  lobbyBtns: { width: '100%', gap: 12, marginTop: 14 },

  liveRoot: { flex: 1, backgroundColor: C.bg, alignItems: 'center', justifyContent: 'center' },
  overlay: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 30 },
  vs: { flexDirection: 'row', alignItems: 'center', gap: 16, marginBottom: 30 },
  who: { alignItems: 'center', gap: 8 },
  name: { fontFamily: FONT.bodyBold, fontSize: 14 },
  vsBadge: { fontFamily: FONT.display, fontSize: 24, color: C.lime, transform: [{ rotate: '-8deg' }] },
  count: { fontFamily: FONT.display, fontSize: 110, color: C.ink, textShadowColor: 'rgba(123,59,255,0.7)', textShadowRadius: 34, textShadowOffset: { width: 0, height: 0 } },
  ready: { fontFamily: FONT.display, letterSpacing: 4, color: C.inkDim, fontSize: 13, marginTop: 12 },
  point: { fontFamily: FONT.display, fontSize: 60, color: C.lime, textShadowColor: 'rgba(212,255,61,0.5)', textShadowRadius: 18, textShadowOffset: { width: 0, height: 0 } },
  pointBy: { flexDirection: 'row', alignItems: 'center', gap: 12, marginTop: 16 },
  delta: { fontFamily: FONT.display, color: C.lime, fontSize: 18 },
});

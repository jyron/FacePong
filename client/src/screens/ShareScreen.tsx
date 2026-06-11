import React, { useState } from 'react';
import { Pressable, Share, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import * as Clipboard from 'expo-clipboard';
import { FaceCoin } from '../components/FaceCoin';
import { ScoreChip } from '../components/ScoreChip';
import { useFaces } from '../faces/FaceStore';
import { C, FONT } from '../theme/tokens';
import { track } from '../analytics';
import type { Slot } from '../../shared/constants';

const TARGETS = [
  { lb: 'Message', ic: '💬' },
  { lb: 'Story', ic: '✨' },
  { lb: 'Save', ic: '⬇️' },
  { lb: 'More', ic: '···' },
];

export function ShareScreen({
  winner,
  winnerName,
  scores,
  code,
  onDone,
}: {
  winner: Slot;
  winnerName: string;
  scores: { p1: number; p2: number };
  code: string;
  onDone: () => void;
}) {
  const { faces } = useFaces();
  const { width, height } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const [copied, setCopied] = useState(false);
  const url = `facepong.gg/r/${code}`;

  const openShare = () => {
    track.resultShared();
    Share.share({ message: `🏓 ${winnerName} won FacePong ${scores.p1}–${scores.p2}! Play me: ${url}` }).catch(() => {});
  };
  const copy = async () => {
    await Clipboard.setStringAsync(url);
    setCopied(true);
    setTimeout(() => setCopied(false), 1400);
  };

  const now = new Date();
  const date = now.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }).toUpperCase();

  return (
    <View style={styles.root}>
      <View style={[styles.content, { paddingTop: insets.top + 24, paddingBottom: insets.bottom + 16 }]}>
        <Pressable style={styles.back} onPress={onDone} hitSlop={12}>
          <Text style={styles.backText}>‹ Done</Text>
        </Pressable>

        <View style={styles.head}>
          <Text style={styles.title}>SHARE THE WIN</Text>
          <Text style={styles.sub}>Send your victory card to the group chat.</Text>
        </View>

        <View style={styles.card}>
          <View style={styles.cardTop}>
            <Text style={styles.brand}>
              <Text style={{ color: C.cyan }}>FACE</Text>
              <Text style={{ color: C.magenta }}>PONG</Text>
            </Text>
            <Text style={styles.cardDate}>{date} · 9:41 PM</Text>
          </View>
          <View style={styles.cardMid}>
            <FaceCoin slot="p1" size={84} uri={faces.p1} />
            <Text style={styles.vs}>VS</Text>
            <FaceCoin slot="p2" size={84} uri={faces.p2} />
          </View>
          <View style={styles.cardResult}>
            <Text style={styles.win}>👑 {winnerName} WINS</Text>
            <View style={{ marginTop: 8 }}>
              <ScoreChip p1={scores.p1} p2={scores.p2} size={28} reversed={winner === 'p2'} />
            </View>
          </View>
          <Text style={styles.cardFoot}>{url.toUpperCase()} · BEST OF 5</Text>
        </View>

        <View style={styles.targets}>
          {TARGETS.map((t) => (
            <Pressable key={t.lb} style={styles.target} onPress={openShare}>
              <View style={styles.targetIc}>
                <Text style={styles.targetEmoji}>{t.ic}</Text>
              </View>
              <Text style={styles.targetLb}>{t.lb}</Text>
            </Pressable>
          ))}
        </View>

        <View style={styles.copyRow}>
          <Text style={styles.url} numberOfLines={1}>
            {url}
          </Text>
          <Pressable style={styles.copyBtn} onPress={copy}>
            <Text style={styles.copyText}>{copied ? 'COPIED' : 'COPY'}</Text>
          </Pressable>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.bg },
  content: { flex: 1, paddingHorizontal: 26 },
  back: { position: 'absolute', left: 18, top: 0, paddingVertical: 8 },
  backText: { fontFamily: FONT.bodyBold, color: C.inkDim, fontSize: 15 },
  head: { alignItems: 'center', marginTop: 28, marginBottom: 18 },
  title: { fontFamily: FONT.display, fontSize: 24, color: C.lime, textShadowColor: 'rgba(212,255,61,0.5)', textShadowRadius: 18, textShadowOffset: { width: 0, height: 0 } },
  sub: { fontFamily: FONT.body, color: C.inkDim, fontSize: 13.5, marginTop: 8 },
  card: { borderRadius: 22, overflow: 'hidden', backgroundColor: '#190f2e', borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)', padding: 20 },
  cardTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  brand: { fontFamily: FONT.display, fontSize: 13 },
  cardDate: { fontFamily: FONT.body, fontSize: 11, color: C.inkFaint, letterSpacing: 0.5 },
  cardMid: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 18, marginVertical: 20 },
  vs: { fontFamily: FONT.display, color: C.inkFaint, fontSize: 16 },
  cardResult: { alignItems: 'center' },
  win: { fontFamily: FONT.display, fontSize: 20, color: C.amber },
  cardFoot: { textAlign: 'center', fontFamily: FONT.body, color: C.inkFaint, fontSize: 11, letterSpacing: 1, marginTop: 16 },
  targets: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 20 },
  target: { alignItems: 'center', gap: 7, flex: 1 },
  targetIc: { width: 54, height: 54, borderRadius: 16, alignItems: 'center', justifyContent: 'center', backgroundColor: C.surface2, borderWidth: 1, borderColor: 'rgba(255,255,255,0.08)' },
  targetEmoji: { fontSize: 22, color: C.ink },
  targetLb: { fontFamily: FONT.body, fontSize: 11, color: C.inkDim },
  copyRow: { flexDirection: 'row', alignItems: 'center', gap: 10, marginTop: 20, backgroundColor: C.surface, borderWidth: 1, borderColor: 'rgba(255,255,255,0.08)', borderRadius: 14, padding: 6, paddingLeft: 16 },
  url: { flex: 1, fontFamily: FONT.body, color: C.inkDim, fontSize: 13 },
  copyBtn: { backgroundColor: C.cyan, borderRadius: 10, paddingVertical: 10, paddingHorizontal: 16 },
  copyText: { fontFamily: FONT.display, fontSize: 12, color: '#04161b' },
});

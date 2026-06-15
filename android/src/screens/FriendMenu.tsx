import React, { useState } from 'react';
import { StyleSheet, Text, TextInput, View, useWindowDimensions } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { NeonButton } from '../components/NeonButton';
import { ArcadeBg } from '../components/ArcadeBg';
import { C, FONT } from '../theme/tokens';

export function FriendMenu({
  onBack,
  onCreate,
  onJoin,
}: {
  onBack: () => void;
  onCreate: () => void;
  onJoin: (code: string) => void;
}) {
  const { width, height } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const [code, setCode] = useState('');

  return (
    <View style={styles.root}>
      <ArcadeBg width={width} height={height} />
      <View style={[styles.content, { paddingTop: insets.top + 24, paddingBottom: insets.bottom + 24 }]}>
        <Text style={styles.title}>PLAY A FRIEND</Text>
        <Text style={styles.sub}>Start a game and send the code, or join one.</Text>

        <View style={styles.block}>
          <NeonButton label="CREATE A GAME" variant="lime" onPress={onCreate} />
        </View>

        <Text style={styles.or}>— OR JOIN WITH A CODE —</Text>
        <TextInput
          value={code}
          onChangeText={(t) => setCode(t.toUpperCase())}
          placeholder="ENTER CODE"
          placeholderTextColor={C.inkFaint}
          autoCapitalize="characters"
          autoCorrect={false}
          style={styles.input}
        />
        <View style={styles.block}>
          <NeonButton label="JOIN" variant="cyan" onPress={() => code.trim() && onJoin(code.trim())} />
          <NeonButton label="BACK" variant="ghost" small onPress={onBack} />
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.bg },
  content: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 34 },
  title: { fontFamily: FONT.display, fontSize: 28, color: C.lime, textShadowColor: 'rgba(212,255,61,0.5)', textShadowRadius: 18, textShadowOffset: { width: 0, height: 0 } },
  sub: { fontFamily: FONT.body, color: C.inkDim, fontSize: 14, textAlign: 'center', marginTop: 10, marginBottom: 30 },
  block: { width: '100%', gap: 12, marginTop: 16 },
  or: { fontFamily: FONT.bodyBold, color: C.inkFaint, fontSize: 11, letterSpacing: 1.5, marginTop: 30, marginBottom: 12 },
  input: {
    width: '100%',
    backgroundColor: C.surface,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.12)',
    borderRadius: 14,
    paddingVertical: 16,
    paddingHorizontal: 18,
    fontFamily: FONT.display,
    fontSize: 22,
    letterSpacing: 4,
    color: C.ink,
    textAlign: 'center',
  },
});

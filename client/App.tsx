import React from 'react';
import { View } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { useFonts } from 'expo-font';
import { Bungee_400Regular } from '@expo-google-fonts/bungee';
import {
  SpaceGrotesk_400Regular,
  SpaceGrotesk_500Medium,
  SpaceGrotesk_700Bold,
} from '@expo-google-fonts/space-grotesk';
import { FaceProvider } from './src/faces/FaceStore';
import { AppRoot } from './src/AppRoot';
import { C } from './src/theme/tokens';

export default function App() {
  const [loaded] = useFonts({
    Bungee_400Regular,
    SpaceGrotesk_400Regular,
    SpaceGrotesk_500Medium,
    SpaceGrotesk_700Bold,
  });

  return (
    <GestureHandlerRootView style={{ flex: 1, backgroundColor: C.bg }}>
      <SafeAreaProvider>
        <FaceProvider>
          {loaded ? <AppRoot /> : <View style={{ flex: 1, backgroundColor: C.bg }} />}
          <StatusBar style="light" />
        </FaceProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

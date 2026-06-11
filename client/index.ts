import { registerRootComponent } from 'expo';
import { initExecutorch } from 'react-native-executorch';
import { ExpoResourceFetcher } from 'react-native-executorch-expo-resource-fetcher';

import App from './App';

// ExecuTorch 0.9 needs its resource-fetcher adapter wired up once at startup
// (it loads model files — bundled or remote). Without this, model loads throw
// "ResourceFetcher adapter is not initialized" and face segmentation silently
// falls back to the raw photo. See faces/segment.ts.
initExecutorch({ resourceFetcher: ExpoResourceFetcher });

// registerRootComponent calls AppRegistry.registerComponent('main', () => App);
// It also ensures that whether you load the app in Expo Go or in a native build,
// the environment is set up appropriately
registerRootComponent(App);

// Pick a face from the photo library or snap a selfie, segment it to a
// transparent cutout on-device, and return it as a PNG data URI. The same data
// URI is what gets sent to the opponent over the network. Falls back to the raw
// JPEG photo if segmentation isn't available (e.g. Expo Go) or fails.
import { Platform, ActionSheetIOS, Alert } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { manipulateAsync, SaveFormat } from 'expo-image-manipulator';
import { cutoutFace } from './segment';

export type PickSource = 'library' | 'camera';

async function toFaceDataUri(uri: string): Promise<string> {
  const out = await manipulateAsync(uri, [{ resize: { width: 384 } }], {
    compress: 0.9,
    format: SaveFormat.JPEG,
    base64: true,
  });
  const jpeg = `data:image/jpeg;base64,${out.base64}`;
  try {
    return await cutoutFace(jpeg);
  } catch {
    return jpeg;
  }
}

export async function pickFace(source: PickSource): Promise<string | null> {
  if (source === 'camera') {
    const perm = await ImagePicker.requestCameraPermissionsAsync();
    if (!perm.granted) return null;
    const res = await ImagePicker.launchCameraAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.9,
      cameraType: ImagePicker.CameraType.front,
    });
    if (res.canceled || !res.assets?.[0]) return null;
    return toFaceDataUri(res.assets[0].uri);
  }

  const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (!perm.granted) return null;
  const res = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ['images'],
    allowsEditing: true,
    aspect: [1, 1],
    quality: 0.9,
  });
  if (res.canceled || !res.assets?.[0]) return null;
  return toFaceDataUri(res.assets[0].uri);
}

// Ask the user where to get the face from, then pick it. `onStart` fires once
// a source has been chosen (i.e. real work is about to happen), so callers can
// show a busy state while the photo is picked and segmented; `onResult` always
// follows it, with null on cancel/failure.
export function chooseFaceSource(
  onResult: (dataUri: string | null) => void,
  onStart?: () => void,
): void {
  const run = async (source: PickSource) => {
    onStart?.();
    try {
      onResult(await pickFace(source));
    } catch {
      onResult(null);
    }
  };

  if (Platform.OS === 'ios') {
    ActionSheetIOS.showActionSheetWithOptions(
      { options: ['Take a selfie', 'Choose a photo', 'Cancel'], cancelButtonIndex: 2, title: 'Your face' },
      (i) => {
        if (i === 0) run('camera');
        else if (i === 1) run('library');
      }
    );
  } else {
    Alert.alert('Your face', undefined, [
      { text: 'Take a selfie', onPress: () => run('camera') },
      { text: 'Choose a photo', onPress: () => run('library') },
      { text: 'Cancel', style: 'cancel' },
    ]);
  }
}

// Holds the two player faces (data URIs) and persists them across launches.
// p1 = local player (cyan), p2 = the face picked for the offline/CPU opponent.
// Online opponents' faces arrive over the network and are kept in match-local
// state (see OnlineGame) — they are never written into this store.
import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import type { Slot } from '../../shared/constants';

export type Faces = { p1: string | null; p2: string | null };

const KEYS: Record<Slot, string> = { p1: 'facepong.p1', p2: 'facepong.p2' };

type Ctx = {
  faces: Faces;
  setFace: (who: Slot, dataUri: string | null) => void;
  ready: boolean;
};

const FaceContext = createContext<Ctx | null>(null);

export function FaceProvider({ children }: { children: React.ReactNode }) {
  const [faces, setFaces] = useState<Faces>({ p1: null, p2: null });
  const [ready, setReady] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        const [p1, p2] = await Promise.all([AsyncStorage.getItem(KEYS.p1), AsyncStorage.getItem(KEYS.p2)]);
        setFaces({ p1: p1 || null, p2: p2 || null });
      } catch {
        // ignore — fall back to defaults
      } finally {
        setReady(true);
      }
    })();
  }, []);

  const setFace = useCallback((who: Slot, dataUri: string | null) => {
    setFaces((f) => ({ ...f, [who]: dataUri }));
    AsyncStorage.setItem(KEYS[who], dataUri ?? '').catch(() => {});
  }, []);

  return <FaceContext.Provider value={{ faces, setFace, ready }}>{children}</FaceContext.Provider>;
}

export function useFaces(): Ctx {
  const ctx = useContext(FaceContext);
  if (!ctx) throw new Error('useFaces must be used within FaceProvider');
  return ctx;
}

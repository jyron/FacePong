// ============================================================================
// FacePong — SINGLE SOURCE OF TRUTH for the client<->server wire protocol.
// Imported by BOTH the Expo client and the Colyseus server so message names
// and payload shapes can never drift apart. The authoritative game *state*
// shape lives in the Colyseus Schema (server/src/schema/PongState.ts) whose
// field names mirror NetStateShape below.
// ============================================================================

export type Mode = 'cpu' | 'quick' | 'friend';

export type Phase = 'waiting' | 'countdown' | 'playing' | 'point' | 'match';

// Client -> server message names.
export const MSG = {
  input: 'input', // { x } local paddle target x (court units)
  face: 'face', // { data } base64 jpeg data URI, sent once on join
  ready: 'ready', // {} player tapped ready / play again
} as const;

export type InputMsg = { x: number };
export type FaceMsg = { data: string };
export type ReadyMsg = Record<string, never>;

// Room creation / join options.
export type JoinOptions = {
  mode: Exclude<Mode, 'cpu'>; // 'quick' | 'friend'
  code?: string; // required to join a friend's private room
  name?: string;
};

// Reference shape of the authoritative state the client reads from the room.
// (The Colyseus Schema mirrors these field names.)
export interface NetPlayerShape {
  sessionId: string;
  slot: 'p1' | 'p2';
  x: number;
  score: number;
  name: string;
  hasFace: boolean;
}
export interface NetStateShape {
  phase: Phase;
  code: string; // friend room code (empty for quick match)
  ballX: number;
  ballY: number;
  rally: number;
  round: number;
  servingSlot: 'p1' | 'p2';
  winnerSlot: '' | 'p1' | 'p2';
  topRally: number;
}

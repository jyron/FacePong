// Authoritative Colyseus state. Field names mirror NetStateShape /
// NetPlayerShape in the shared protocol (android/shared/protocol.ts) so the
// client reads them by the same names. Uses defineTypes (functional API) to
// avoid decorator build configuration.
import { Schema, MapSchema, defineTypes } from '@colyseus/schema';

export class Player extends Schema {
  sessionId = '';
  slot = 'p1'; // 'p1' (canonical bottom) | 'p2' (canonical top)
  x = 195; // paddle center x in court units (canonical frame)
  score = 0;
  name = 'Player';
  hasFace = false;
  faceData = ''; // the player's segmented face cutout (data:image/png URI)
}
defineTypes(Player, {
  sessionId: 'string',
  slot: 'string',
  x: 'number',
  score: 'number',
  name: 'string',
  hasFace: 'boolean',
  faceData: 'string',
});

export class PongState extends Schema {
  phase = 'waiting'; // waiting | countdown | playing | point | match
  code = ''; // friend-room join code (room id); '' for quick match
  ballX = 195;
  ballY = 422;
  rally = 0;
  round = 1;
  servingSlot = 'p1';
  scorerSlot = ''; // who won the most recent point (drives the Point screen)
  winnerSlot = '';
  topRally = 0;
  countdown = 0; // seconds remaining shown during countdown
  players = new MapSchema<Player>();
}
defineTypes(PongState, {
  phase: 'string',
  code: 'string',
  ballX: 'number',
  ballY: 'number',
  rally: 'number',
  round: 'number',
  servingSlot: 'string',
  scorerSlot: 'string',
  winnerSlot: 'string',
  topRally: 'number',
  countdown: 'number',
  players: { map: Player },
});

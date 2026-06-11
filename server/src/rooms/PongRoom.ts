// Authoritative FacePong room. Runs the SAME physics engine the client uses for
// CPU play (client/shared/engine.ts) at 60Hz; Colyseus patches state to clients
// at its default rate. Canonical frame: p1 = bottom, p2 = top. Each client
// renders itself at the bottom by flipping Y when it is p2.
import { Room, Client } from '@colyseus/core';
import { PongState, Player } from '../schema/PongState';
import { createEngineState, serve, step, type EngineState } from '../../../client/shared/engine';
import { COURT, TARGET_SCORE, clampPaddleX, type Slot } from '../../../client/shared/constants';
import { track } from '../analytics';

const CX = COURT.W / 2;

export class PongRoom extends Room<PongState> {
  maxClients = 2;

  private engine: EngineState = createEngineState();
  private targets: Record<string, number> = {};
  private faces: Partial<Record<Slot, string>> = {};
  private pointTimer: { clear: () => void } | undefined;
  private matchStartedAt = 0;

  // 'friend' for code rooms, 'quick' for matchmaking (code "")
  private matchMode() {
    return this.state.code ? 'friend' : 'quick';
  }

  onCreate(options: { mode?: string; code?: string } = {}) {
    this.setState(new PongState());

    // `code` is the filterBy key: "" for quick match, an uppercase share code
    // for a friend room. Echo it into state so the host can display it. We do
    // NOT setPrivate() — private rooms are excluded from matchmaking, which
    // would stop a friend joining by code; the unique code already keeps these
    // rooms separate from quick match (code "").
    this.state.code = (options.code || '').toUpperCase();

    this.onMessage('input', (client, msg: { x?: number }) => {
      if (typeof msg?.x === 'number') this.targets[client.sessionId] = clampPaddleX(msg.x);
    });

    this.onMessage('face', (client, msg: { data?: string }) => {
      const p = this.state.players.get(client.sessionId);
      if (!p || typeof msg?.data !== 'string') return;
      // Sanity caps: must look like an image data URI and fit comfortably
      // under the transport's 2MB maxPayload (see index.ts).
      if (!msg.data.startsWith('data:image/') || msg.data.length > 1.5 * 1024 * 1024) return;
      p.hasFace = true;
      this.faces[p.slot as Slot] = msg.data;
      this.broadcast('face', { slot: p.slot, data: msg.data }, { except: client });
    });

    this.setSimulationInterval(() => this.update(), 1000 / 60);
  }

  onJoin(client: Client, options: { name?: string } = {}) {
    // Take whichever slot is free — after a mid-match leave the remaining
    // player may be p2, so "second to join" does not imply p2.
    let p1Taken = false;
    this.state.players.forEach((p) => {
      if (p.slot === 'p1') p1Taken = true;
    });
    const slot: Slot = p1Taken ? 'p2' : 'p1';
    const p = new Player();
    p.sessionId = client.sessionId;
    p.slot = slot;
    p.x = CX;
    p.name = (options.name || (slot === 'p1' ? 'P1' : 'P2')).slice(0, 12);
    this.state.players.set(client.sessionId, p);
    this.targets[client.sessionId] = CX;

    // hand the newcomer any face the opponent already submitted
    for (const s of ['p1', 'p2'] as Slot[]) {
      if (s !== slot && this.faces[s]) client.send('face', { slot: s, data: this.faces[s] });
    }

    if (this.state.players.size === 2) this.startMatch();
  }

  onLeave(client: Client) {
    // A leave during an unfinished match is an abandonment (quit/disconnect).
    if (this.state.phase !== 'waiting' && this.state.phase !== 'match') {
      track('online_match_abandoned', {
        mode: this.matchMode(),
        duration_s: Math.floor((Date.now() - this.matchStartedAt) / 1000),
      });
    }
    const leaver = this.state.players.get(client.sessionId);
    if (leaver) delete this.faces[leaver.slot as Slot];
    this.state.players.delete(client.sessionId);
    delete this.targets[client.sessionId];
    if (this.pointTimer) this.pointTimer.clear();
    // opponent left — drop back to waiting
    this.state.phase = 'waiting';
    this.state.winnerSlot = '';
    this.state.scorerSlot = '';
  }

  // ---- flow ----
  private startMatch() {
    this.matchStartedAt = Date.now();
    track('online_match_started', { mode: this.matchMode() });
    this.state.players.forEach((p) => (p.score = 0));
    this.state.round = 1;
    this.state.topRally = 0;
    this.state.winnerSlot = '';
    this.state.scorerSlot = '';
    this.beginCountdown('p1');
  }

  private beginCountdown(serveTo: Slot) {
    this.state.phase = 'countdown';
    this.state.countdown = 3;
    // Park the ball at center for the countdown so clients never see it (or
    // interpolate it) at the previous point's out-of-bounds position.
    this.state.ballX = CX;
    this.state.ballY = COURT.H / 2;
    this.state.rally = 0;
    this.state.servingSlot = serveTo;
    const id = this.clock.setInterval(() => {
      this.state.countdown -= 1;
      if (this.state.countdown <= 0) {
        id.clear();
        this.serveAndPlay(serveTo);
      }
    }, 850);
  }

  private serveAndPlay(serveTo: Slot) {
    serve(this.engine, serveTo);
    // Paddles are NOT recentered: players may position during the countdown.
    this.state.ballX = this.engine.ballX;
    this.state.ballY = this.engine.ballY;
    this.state.rally = 0;
    this.state.scorerSlot = '';
    this.state.phase = 'playing';
  }

  private players() {
    let p1: Player | undefined;
    let p2: Player | undefined;
    this.state.players.forEach((p) => (p.slot === 'p1' ? (p1 = p) : (p2 = p)));
    return { p1, p2 };
  }

  private update() {
    const { p1, p2 } = this.players();
    if (!p1 || !p2) return;

    // Paddles track player input in every phase (so players can move during
    // the countdown / point screens); the ball only advances while playing.
    const s = this.engine;
    const t1 = this.targets[p1.sessionId] ?? s.p1x;
    const t2 = this.targets[p2.sessionId] ?? s.p2x;
    s.p1x += (t1 - s.p1x) * 0.5;
    s.p2x += (t2 - s.p2x) * 0.5;
    p1.x = s.p1x;
    p2.x = s.p2x;

    if (this.state.phase !== 'playing') return;

    const r = step(s);

    this.state.ballX = s.ballX;
    this.state.ballY = s.ballY;
    this.state.rally = s.rally;
    if (s.rally > this.state.topRally) this.state.topRally = s.rally;

    if (r.scored) this.handlePoint(r.scored);
  }

  private handlePoint(slot: Slot) {
    const { p1, p2 } = this.players();
    const scorer = slot === 'p1' ? p1 : p2;
    if (scorer) scorer.score += 1;
    this.state.scorerSlot = slot;
    this.state.phase = 'point';

    const over = !!scorer && scorer.score >= TARGET_SCORE;
    this.pointTimer = this.clock.setTimeout(() => {
      if (over) {
        this.state.phase = 'match';
        this.state.winnerSlot = slot;
        track('online_match_completed', {
          mode: this.matchMode(),
          score_p1: p1?.score ?? 0,
          score_p2: p2?.score ?? 0,
          top_rally: this.state.topRally,
          rounds: this.state.round,
          duration_s: Math.floor((Date.now() - this.matchStartedAt) / 1000),
        });
      } else {
        this.state.round += 1;
        this.beginCountdown(slot === 'p1' ? 'p2' : 'p1');
      }
    }, 2400);
  }
}

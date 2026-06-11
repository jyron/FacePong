import { Client, type Room } from 'colyseus.js';
import { SERVER_URL } from './config';

const client = new Client(SERVER_URL);

export type { Room };

// Unambiguous code alphabet (no 0/O, 1/I/L) for friend share codes.
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export const makeFriendCode = (): string =>
  Array.from({ length: 4 }, () => CODE_ALPHABET[(Math.random() * CODE_ALPHABET.length) | 0]).join('');

// Quick Match — all public players share code "" and match each other.
export const joinQuick = (name: string): Promise<Room> =>
  client.joinOrCreate('pong', { code: '', mode: 'quick', name });

// Play a Friend — host creates a private room carrying the share code.
export const createFriend = (code: string, name: string): Promise<Room> =>
  client.create('pong', { code: code.toUpperCase(), mode: 'friend', name });

// Friend joins by code (case-insensitive; matched via filterBy on the server).
export const joinFriend = (code: string, name: string): Promise<Room> =>
  client.join('pong', { code: code.toUpperCase(), mode: 'friend', name });

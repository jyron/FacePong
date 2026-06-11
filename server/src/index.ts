import http from 'http';
import { Server } from '@colyseus/core';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { PongRoom } from './rooms/PongRoom';

const port = Number(process.env.PORT) || 2567;

// Plain HTTP server so Railway's health check on "/" gets a 200.
const httpServer = http.createServer((req, res) => {
  if (req.url === '/' || req.url === '/health') {
    res.writeHead(200, { 'content-type': 'text/plain' });
    res.end('FacePong server ok');
    return;
  }
  res.writeHead(404);
  res.end();
});

const gameServer = new Server({
  transport: new WebSocketTransport({
    server: httpServer,
    // Default maxPayload is 4KB and ws closes the socket (code 1009) on any
    // bigger message — but players exchange their face cutouts as base64 PNG
    // data URIs (hundreds of KB). PongRoom enforces the per-message cap.
    maxPayload: 2 * 1024 * 1024,
  }),
});

// Single room type, segregated by a `code` field:
//   • Quick match  -> code "" (all public players match each other)
//   • Play a friend -> a clean uppercase share code (host creates, friend joins)
gameServer.define('pong', PongRoom).filterBy(['code']);

gameServer.listen(port);
console.log(`FacePong server listening on :${port}`);

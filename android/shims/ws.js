// React Native ships a global WebSocket. colyseus.js does
//   const WebSocket = globalThis.WebSocket || require('ws')
// so the Node `ws` package is never used here — this shim just satisfies the
// require so Metro doesn't pull `ws` (and Node's `stream`) into the RN bundle.
module.exports = globalThis.WebSocket;

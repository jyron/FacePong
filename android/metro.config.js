const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const config = getDefaultConfig(__dirname);

// Bundle the ExecuTorch selfie-segmentation model (.pte) as an app asset so it
// ships inside the binary — no runtime download (see faces/segment.ts).
config.resolver.assetExts.push('pte');

// colyseus.js's transport does `globalThis.WebSocket || require('ws')`. On React
// Native the global WebSocket wins, but the bare `require('ws')` still makes
// Metro try to bundle the Node `ws` package (which needs Node's `stream`).
// Force-resolve `ws` to a tiny shim that exposes the global WebSocket.
const wsShim = path.resolve(__dirname, 'shims/ws.js');
// @colyseus/httpie defaults to its Node build (imports http/https/url); point
// it at the fetch build, which uses React Native's global fetch.
const httpieFetch = path.resolve(__dirname, 'node_modules/@colyseus/httpie/fetch/index.mjs');
const forced = { ws: wsShim, '@colyseus/httpie': httpieFetch };
const defaultResolveRequest = config.resolver.resolveRequest;
config.resolver.resolveRequest = (context, moduleName, platform) => {
  if (forced[moduleName]) {
    return { type: 'sourceFile', filePath: forced[moduleName] };
  }
  return (defaultResolveRequest ?? context.resolveRequest)(context, moduleName, platform);
};

module.exports = config;

module.exports = function (api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
    plugins: [
      // @colyseus/schema's ESM build uses static class blocks, which SDK 55's
      // preset doesn't down-level on its own.
      '@babel/plugin-transform-class-static-block',
      // Reanimated 4 uses the worklets plugin; it must be listed last.
      'react-native-worklets/plugin',
    ],
  };
};

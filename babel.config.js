// Needed by the per-platform jest presets. `jest-expo/ios` and `jest-expo/android`
// replace the root preset's babel options with their own `caller` settings, which
// drops the preset that came with them — so babel falls back to the project
// config, and without one React Native's Flow-typed jest setup fails to parse.
module.exports = {
  presets: ['babel-preset-expo'],
};

// Consumed by React Native autolinking (community CLI and Expo). Only iOS ships
// native code: Android and web fall back to React Native's own TextInput,
// because the IME composition bug this library fixes is specific to Fabric on
// iOS.
module.exports = {
  dependency: {
    platforms: {
      android: null,
    },
  },
};

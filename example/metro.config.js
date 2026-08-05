const path = require('path');

const { getDefaultConfig } = require('expo/metro-config');

const projectRoot = __dirname;
const workspaceRoot = path.resolve(projectRoot, '..');

const config = getDefaultConfig(projectRoot);

// Watch the library sources so edits trigger a rebuild. Only `src` is watched —
// pointing Metro at the whole workspace root would also pull in its
// `node_modules` under a second path.
config.watchFolders = [path.resolve(workspaceRoot, 'src')];

// Resolve `react-native-ime-text-input` straight to its sources.
//
// The npm workspace links the package as `node_modules/react-native-ime-text-input -> ..`,
// and because the package root *is* the workspace root, resolving through that
// symlink makes every hoisted dependency reachable under two different paths
// (`node_modules/react-native` and
// `node_modules/react-native-ime-text-input/node_modules/react-native`). Metro then treats
// them as separate modules and its import-collapsing pass fails. Aliasing to
// the real path sidesteps the symlink entirely — and using `src` rather than
// `build` means library edits show up without a rebuild.
const librarySource = path.resolve(workspaceRoot, 'src');
const defaultResolveRequest = config.resolver.resolveRequest;

config.resolver.resolveRequest = (context, moduleName, platform) => {
  if (moduleName === 'react-native-ime-text-input') {
    return context.resolveRequest(context, librarySource, platform);
  }
  return defaultResolveRequest
    ? defaultResolveRequest(context, moduleName, platform)
    : context.resolveRequest(context, moduleName, platform);
};

// npm workspaces hoist shared dependencies to the root, so both locations have
// to be searched. Hierarchical lookup stays on: npm still nests some packages
// and disabling it breaks them.
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, 'node_modules'),
  path.resolve(workspaceRoot, 'node_modules'),
];

module.exports = config;

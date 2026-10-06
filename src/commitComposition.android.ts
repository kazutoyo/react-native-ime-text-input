import { findNodeHandle, NativeModules } from 'react-native';

type ImeTextInputModule = { commitComposition: (reactTag: number) => void };

/**
 * Ends the composition natively (`ImeTextInputModule.kt` explains why React
 * Native's own TextInput keeps it across a value update).
 *
 * Missing module — an app binary built before this version — degrades to the
 * old no-op instead of throwing, so a JS update can ship ahead of a rebuild.
 */
export function commitCompositionOn(node: Parameters<typeof findNodeHandle>[0]): void {
  const module = NativeModules.RNImeTextInputModule as ImeTextInputModule | undefined;
  const tag = findNodeHandle(node);
  if (module && tag != null) {
    module.commitComposition(tag);
  }
}

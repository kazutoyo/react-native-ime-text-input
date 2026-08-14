/**
 * React Native's registry of text inputs and which one currently holds focus.
 *
 * `keyboardShouldPersistTaps`, `Keyboard.dismiss()` and `TextInput.State` all
 * resolve "which input should I blur" through this module. Its public surface
 * (`TextInput.State`) re-exports only the read side, so an input that is not
 * React Native's own has to reach for the internal path to take part at all —
 * and one that does not take part makes those APIs no-ops, silently.
 *
 * The module ships no type declarations, hence this one.
 */
declare module 'react-native/Libraries/Components/TextInput/TextInputState' {
  /** A native component's ref — opaque here; only identity matters. */
  type HostInstance = object;

  const TextInputState: {
    currentlyFocusedInput(): HostInstance | null;
    focusInput(instance: HostInstance | null): void;
    blurInput(instance: HostInstance | null): void;
    registerInput(instance: HostInstance): void;
    unregisterInput(instance: HostInstance): void;
    isTextInput(instance: HostInstance | null): boolean;
  };

  export default TextInputState;
}

/**
 * A ref that might be able to move the selection.
 *
 * `setSelection` is React Native's own method. `setSelectionRange` is the DOM
 * one, which is what a react-native-web ref ultimately points at.
 */
export type SelectionCapableNode = {
  setSelection?: (start: number, end: number) => void;
  setSelectionRange?: (start: number, end: number) => void;
};

/**
 * Moves the selection through whichever method the node actually has.
 *
 * React Native's `TextInput` ref exposes `setSelection` on Android, but
 * react-native-web builds its ref from an `imperativeRef` that only adds
 * `clear` and `isFocused` — so on web the call landed on a host `<input>` /
 * `<textarea>` that has no `setSelection`, and threw. Falling back to the DOM
 * API keeps one ref contract across every platform.
 */
export function setSelectionOn(
  node: SelectionCapableNode | null | undefined,
  start: number,
  end: number
): void {
  if (!node) {
    return;
  }

  if (typeof node.setSelection === 'function') {
    node.setSelection(start, end);
    return;
  }

  if (typeof node.setSelectionRange === 'function') {
    node.setSelectionRange(start, end);
    return;
  }

  if (__DEV__) {
    console.warn(
      'react-native-ime-text-input: `ref.setSelection()` did nothing — the underlying ' +
        'node exposes neither `setSelection` nor `setSelectionRange`. ' +
        'Use the `selection` prop instead, which every platform honours.'
    );
  }
}

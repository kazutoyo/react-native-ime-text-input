import type { Ref } from 'react';
import type { TextInputProps as RNTextInputProps } from 'react-native';

/**
 * Imperative handle, mirroring React Native's `TextInput` methods.
 */
export type TextInputRef = {
  focus: () => void;
  blur: () => void;
  clear: () => void;
  isFocused: () => boolean;
  setSelection: (start: number, end: number) => void;
};

/**
 * Props accepted by this library's `TextInput` — React Native's own, unchanged
 * apart from the ref type.
 *
 * Nothing is removed from the type even though a handful of props have no
 * effect on iOS (see `UNSUPPORTED_PROPS`). Only iOS is replaced; on Android and
 * web this renders React Native's `TextInput`, where those props work normally.
 * Stripping them from the type would make a cross-platform component fail to
 * compile over a prop that is perfectly valid on the platform it targets.
 *
 * The iOS implementation warns once per prop name in `__DEV__` instead, so the
 * gap is visible where it actually exists rather than everywhere.
 */
export interface TextInputProps extends Omit<RNTextInputProps, 'ref'> {
  ref?: Ref<TextInputRef>;
}

import type { Ref } from 'react';
import type { TextInputProps as RNTextInputProps } from 'react-native';

/**
 * Imperative handle: React Native's `TextInput` methods, plus one it has no
 * equivalent for.
 */
export type TextInputRef = {
  focus: () => void;
  blur: () => void;
  clear: () => void;
  isFocused: () => boolean;
  setSelection: (start: number, end: number) => void;
  /**
   * Confirms an in-progress IME conversion, so that a value set right after it
   * replaces the composed text instead of being queued behind it.
   *
   * Call it before inserting text into a field the user may be composing in —
   * an emoji picker, a mention bar, a formatting button. Without it the
   * insertion is held until the conversion commits and then applied on top of
   * it, and the conversion result is lost.
   *
   * ```ts
   * const insertEmoji = (emoji: string) => {
   *   ref.current?.commitComposition();
   *   setValue((current) => current + emoji);
   * };
   * ```
   *
   * The confirmation takes the composed text as it stands, the same as tapping
   * elsewhere in the field would — it does not pick a conversion candidate.
   *
   * iOS only. On Android and web this is a no-op: React Native's own
   * `TextInput` renders there, and their IMEs commit on their own when the
   * value changes.
   */
  commitComposition: () => void;
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

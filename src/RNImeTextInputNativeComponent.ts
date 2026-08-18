import {
  codegenNativeCommands,
  codegenNativeComponent,
  type CodegenTypes,
  type ColorValue,
  type HostComponent,
  type ViewProps,
} from 'react-native';

/**
 * SYNC: this spec is the source of truth for the native prop surface. Adding a
 * prop touches, in order:
 *
 *   1. here
 *   2. `ios/RNImeTextInput.mm` — `updateProps` (and `RNImeTextInputAttributes` if it
 *      is typography)
 *   3. `src/TextInput.ios.tsx` — mapping from React Native's prop
 *   4. `src/splitStyle.ts` — if it comes from `style` rather than a prop
 *
 * Nothing verifies that these stay in step.
 */
export interface NativeProps extends ViewProps {
  // -- Text --

  /** The controlled value. Absent means the field owns its own text. */
  text?: string;

  /**
   * Bumped by JavaScript after every user edit.
   *
   * React Native reverts a controlled field when the parent does not accept the
   * change. If `value` never changes then neither does `text`, so nothing would
   * be sent down; this always changes, which gives the native side a chance to
   * re-assert the value JavaScript wants.
   */
  textRevision?: CodegenTypes.WithDefault<CodegenTypes.Int32, 0>;

  /**
   * The `eventCount` from the last `onChangeText` JavaScript has processed.
   * The native side refuses to apply `text` while this lags its own counter —
   * that value predates a keystroke the user has already made, and applying it
   * would rewind the field only for the in-flight change event to bounce it
   * back. Mirrors React Native's `mostRecentEventCount`.
   */
  mostRecentEventCount?: CodegenTypes.WithDefault<CodegenTypes.Int32, 0>;

  placeholder?: string;
  placeholderTextColor?: ColorValue;
  multiline?: CodegenTypes.WithDefault<boolean, false>;
  /** 0 means unlimited, matching React Native. */
  maxLength?: CodegenTypes.WithDefault<CodegenTypes.Int32, 0>;

  // -- Typography --

  /** Whether the font follows the system text size setting. */
  allowFontScaling?: CodegenTypes.WithDefault<boolean, true>;
  /** Caps that scaling. 0 — and anything below 1 — means no cap. */
  maxFontSizeMultiplier?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  fontSize?: CodegenTypes.WithDefault<CodegenTypes.Double, 17>;
  /**
   * Every enum-ish prop here is a plain string rather than a literal union.
   *
   * Codegen turns a union into C++ enum members named after each value, which
   * breaks on values a C++ identifier cannot express — the '100'..'900' weights
   * start with a digit, 'underline line-through' contains a space — and ties
   * this file to generated member names that differ by React Native version.
   * Parsing natively instead keeps the boundary stable; React Native types its
   * own `AndroidTextInputNativeComponent` fontWeight the same way.
   *
   * Empty string means "not set", and the native side falls back to the default.
   */
  fontWeight?: string;
  fontFamily?: string;
  fontStyle?: string;
  color?: ColorValue;
  textAlign?: string;
  /** Points. 0 means unset — the font's natural line height is used. */
  lineHeight?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  /** Points. 0 means no extra tracking, which is also the platform default. */
  letterSpacing?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  /**
   * A free string for the same reason as `fontWeight`: the
   * 'underline line-through' value contains a space, which codegen would turn
   * into an invalid C++ enum member.
   */
  textDecorationLine?: string;
  textDecorationColor?: ColorValue;
  textDecorationStyle?: string;
  textShadowColor?: ColorValue;
  /** Split into two scalars rather than an object prop, which codegen handles less predictably. */
  textShadowOffsetWidth?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  textShadowOffsetHeight?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  textShadowRadius?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  writingDirection?: string;

  // -- Behaviour --

  editable?: CodegenTypes.WithDefault<boolean, true>;
  secureTextEntry?: CodegenTypes.WithDefault<boolean, false>;
  autoFocus?: CodegenTypes.WithDefault<boolean, false>;
  selectTextOnFocus?: CodegenTypes.WithDefault<boolean, false>;
  clearTextOnFocus?: CodegenTypes.WithDefault<boolean, false>;
  submitBehavior?: string;
  caretHidden?: CodegenTypes.WithDefault<boolean, false>;
  /** Suppresses the cut/copy/paste edit menu, as React Native core does. */
  contextMenuHidden?: CodegenTypes.WithDefault<boolean, false>;
  selectionColor?: ColorValue;

  // -- Keyboard --

  keyboardType?: string;
  returnKeyType?: string;
  autoCapitalize?: string;
  autoCorrect?: CodegenTypes.WithDefault<boolean, true>;
  /** 'auto' follows `autoCorrect`, matching React Native's behaviour. */
  spellCheck?: string;
  keyboardAppearance?: string;
  enablesReturnKeyAutomatically?: CodegenTypes.WithDefault<boolean, false>;
  textContentType?: string;
  /** 'auto' leaves UIKit's own default, which is not the same as 'yes'. */
  smartInsertDelete?: string;
  /** A password-rules descriptor; empty means none. */
  passwordRules?: string;
  /** Single-line only — `UITextView` has no clear button. Empty means 'never'. */
  clearButtonMode?: string;
  /**
   * Title for the Done button UIKit gets no return key for. Empty falls back to
   * a title derived from `returnKeyType`, as React Native core does.
   */
  inputAccessoryViewButtonLabel?: string;
  /**
   * Matched against an `InputAccessoryView`'s `nativeID`. React Native's own
   * component walks the window looking for a field carrying this, so the value
   * only has to reach the UIKit view — nothing here reads it back.
   */
  inputAccessoryViewID?: string;

  // -- Events --
  //
  // Named `onInput*` where React Native's `View` already declares an event of
  // the same name: registering `onFocus` / `onBlur` / `onKeyPress` again makes
  // React Native throw "event cannot be both direct and bubbling".

  onChangeText?: CodegenTypes.DirectEventHandler<
    Readonly<{ text: string; eventCount: CodegenTypes.Int32 }>
  >;
  onInputFocus?: CodegenTypes.DirectEventHandler<Readonly<{ text: string }>>;
  onInputBlur?: CodegenTypes.DirectEventHandler<Readonly<{ text: string }>>;
  onSubmit?: CodegenTypes.DirectEventHandler<Readonly<{ text: string }>>;
  onSelectionChange?: CodegenTypes.DirectEventHandler<Readonly<{ start: CodegenTypes.Int32; end: CodegenTypes.Int32 }>>;
  onContentSizeChange?: CodegenTypes.DirectEventHandler<Readonly<{ width: CodegenTypes.Double; height: CodegenTypes.Double }>>;
  onInputKeyPress?: CodegenTypes.DirectEventHandler<Readonly<{ key: string }>>;
}

export type RNImeTextInputViewType = HostComponent<NativeProps>;

interface NativeCommands {
  focus: (viewRef: React.ElementRef<RNImeTextInputViewType>) => void;
  blur: (viewRef: React.ElementRef<RNImeTextInputViewType>) => void;
  clear: (viewRef: React.ElementRef<RNImeTextInputViewType>) => void;
  setSelection: (
    viewRef: React.ElementRef<RNImeTextInputViewType>,
    start: CodegenTypes.Int32,
    end: CodegenTypes.Int32
  ) => void;
  commitComposition: (viewRef: React.ElementRef<RNImeTextInputViewType>) => void;
}

export const Commands: NativeCommands = codegenNativeCommands<NativeCommands>({
  supportedCommands: ['focus', 'blur', 'clear', 'setSelection', 'commitComposition'],
});

export default codegenNativeComponent<NativeProps>('RNImeTextInput') as RNImeTextInputViewType;

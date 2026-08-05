import type { TextStyle, ViewStyle } from 'react-native';

/** The font weights the native side can express. */
export type FontWeightValue =
  | 'normal'
  | 'bold'
  | '100'
  | '200'
  | '300'
  | '400'
  | '500'
  | '600'
  | '700'
  | '800'
  | '900';

/** Text properties the native view takes as props rather than as style. */
export type TextOnlyStyle = {
  fontSize?: number;
  fontWeight?: FontWeightValue;
  fontFamily?: string;
  fontStyle?: 'normal' | 'italic';
  color?: string;
  textAlign?: 'left' | 'right' | 'center' | 'justify';
  lineHeight?: number;
  letterSpacing?: number;
  textDecorationLine?: string;
  textDecorationColor?: string;
  textDecorationStyle?: string;
  textShadowColor?: string;
  textShadowOffset?: { width: number; height: number };
  textShadowRadius?: number;
  writingDirection?: string;
};

export type SplitStyle = {
  /** Everything the native `UIView` renders itself. */
  viewStyle: ViewStyle;
  /** Typography, forwarded as props to the backing text view. */
  text: TextOnlyStyle;
  /** Text properties that were dropped because they have no equivalent. */
  unsupported: string[];
};

/**
 * Text properties that pass straight through to a prop of the same name.
 *
 * Several of these become `NSAttributedString` attributes natively. Text
 * attributes are what break IME composition in React Native, but only because
 * it reapplies them mid-conversion and lets no-op shadow/background attributes
 * through. The native side here defers every attribute update until the
 * conversion commits and never emits those no-op attributes, so they are safe
 * to support.
 */
const TEXT_KEYS = new Set<string>([
  'fontSize',
  'fontFamily',
  'fontStyle',
  'color',
  'lineHeight',
  'letterSpacing',
  'textDecorationLine',
  'textDecorationColor',
  'textDecorationStyle',
  'textShadowColor',
  'textShadowOffset',
  'textShadowRadius',
  'writingDirection',
]);

/** Text properties UIKit has no equivalent for. */
const UNSUPPORTED_TEXT_KEYS = new Set<string>([
  'textTransform',
  'fontVariant',
  'includeFontPadding',
  'verticalAlign',
  'textAlignVertical',
]);

const FONT_WEIGHTS = new Set([
  'normal',
  'bold',
  '100',
  '200',
  '300',
  '400',
  '500',
  '600',
  '700',
  '800',
  '900',
]);

/**
 * React Native also accepts named weights ('medium', 'semibold', …); they map
 * to the same numeric scale UIKit uses (RCTFont's table).
 */
const NAMED_FONT_WEIGHTS: Record<string, FontWeightValue> = {
  ultralight: '100',
  thin: '200',
  light: '300',
  regular: '400',
  medium: '500',
  semibold: '600',
  condensedBold: '700',
  condensed: '400',
  heavy: '800',
  black: '900',
};

/**
 * Splits a flattened React Native `TextStyle` into the view style the native
 * view can render directly and the typography it needs as props.
 *
 * Anything unrecognised stays in `viewStyle` rather than being dropped: an
 * unknown key is far more likely to be a React Native style property this
 * library has not heard of than a mistake, and the native view is a plain
 * `UIView` that React Native styles normally.
 *
 * Pass an already-flattened style (`StyleSheet.flatten(style)`); this function
 * stays free of React Native runtime imports so it can be tested in isolation.
 */
export function splitStyle(style: TextStyle): SplitStyle {
  const viewStyle: Record<string, unknown> = {};
  const text: Record<string, unknown> = {};
  const unsupported: string[] = [];

  for (const [key, value] of Object.entries(style)) {
    if (value === undefined) {
      continue;
    }

    if (UNSUPPORTED_TEXT_KEYS.has(key)) {
      unsupported.push(key);
    } else if (TEXT_KEYS.has(key)) {
      text[key] = value;
    } else if (key === 'fontWeight') {
      // React Native accepts `600`, `'600'`, and named weights like
      // `'semibold'`; the native side wants the numeric string.
      const weight = String(value);
      if (FONT_WEIGHTS.has(weight)) {
        text.fontWeight = weight;
      } else if (weight in NAMED_FONT_WEIGHTS) {
        text.fontWeight = NAMED_FONT_WEIGHTS[weight];
      } else {
        unsupported.push(key);
      }
    } else if (key === 'textAlign') {
      // `auto` is the platform default, so dropping it changes nothing.
      if (value !== 'auto') {
        text.textAlign = value;
      }
    } else {
      viewStyle[key] = value;
    }
  }

  return {
    viewStyle: viewStyle as ViewStyle,
    text: text as TextOnlyStyle,
    unsupported,
  };
}

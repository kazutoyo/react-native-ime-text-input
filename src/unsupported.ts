/**
 * React Native `TextInput` props that have no effect **on iOS** here.
 *
 * Two different reasons are mixed together, and the distinction matters when
 * deciding what to implement next:
 *
 * - UIKit exposes nothing equivalent on a text input, so React Native's own iOS
 *   implementation ignores them too — the Android-only ones
 *   (`disableFullscreenUI`, `importantForAutofill`, `inlineImageLeft`,
 *   `inlineImagePadding`, `returnKeyLabel`, `showSoftInputOnFocus`,
 *   `textBreakStrategy`, `underlineColorAndroid`), plus `blurOnSubmit`, which
 *   is React Native's own deprecated alias for `submitBehavior`.
 * - Simply not implemented here yet, though UIKit could do it and React Native
 *   core does: `inputAccessoryViewID` and `scrollEnabled` among them.
 *
 * They stay in the prop type either way: only iOS is replaced, and on Android
 * and web React Native's own `TextInput` honours them. Removing them from the
 * type would break a cross-platform component over a prop that is valid on the
 * platform it targets. The iOS implementation warns instead.
 *
 * Listed explicitly rather than inferred, so a prop React Native adds later is
 * passed through quietly instead of being flagged as broken.
 */
export const UNSUPPORTED_PROPS = [
  'blurOnSubmit',
  'dataDetectorTypes',
  'disableFullscreenUI',
  'importantForAutofill',
  'inlineImageLeft',
  'inlineImagePadding',
  'inputAccessoryViewID',
  'lineBreakStrategyIOS',
  'onScroll',
  'rejectResponderTermination',
  'returnKeyLabel',
  'scrollEnabled',
  'showSoftInputOnFocus',
  'textBreakStrategy',
  'underlineColorAndroid',
] as const;

export type UnsupportedPropName = (typeof UNSUPPORTED_PROPS)[number];

/** What kind of thing was dropped, used to phrase the warning. */
export type UnsupportedKind = 'prop' | 'style' | 'method';

const UNSUPPORTED_SET: ReadonlySet<string> = new Set(UNSUPPORTED_PROPS);

const warned = new Set<string>();

/**
 * Returns the names of props that were passed but have no effect on iOS.
 *
 * A prop explicitly set to `undefined` counts as absent — spreading a props
 * object routinely produces those, and warning about them would be noise.
 */
export function findUnsupportedProps(props: Record<string, unknown>): string[] {
  const found: string[] = [];

  for (const [name, value] of Object.entries(props)) {
    if (value !== undefined && UNSUPPORTED_SET.has(name)) {
      found.push(name);
    }
  }

  return found;
}

const DESCRIPTIONS: Record<UnsupportedKind, string> = {
  prop: 'prop',
  style: 'style property',
  method: 'ref method',
};

/**
 * Warns about dropped props, style properties, or ref methods — once per name
 * for the lifetime of the JS runtime, so a component that re-renders on every
 * keystroke does not flood the console.
 *
 * Only the iOS implementation calls this. Silently discarding these would be
 * worse than the missing feature itself: a migrated screen would look like it
 * works while a prop quietly does nothing.
 */
export function warnUnsupported(kind: UnsupportedKind, names: readonly string[]): void {
  if (!__DEV__) {
    return;
  }

  for (const name of names) {
    const key = `${kind}:${name}`;
    if (warned.has(key)) {
      continue;
    }
    warned.add(key);

    console.warn(
      `react-native-ime-text-input: the \`${name}\` ${DESCRIPTIONS[kind]} has no effect on iOS ` +
        'and was ignored. It still works on Android and web, which render ' +
        "React Native's own TextInput."
    );
  }
}

/** Clears the "already warned" memory. Intended for tests. */
export function resetUnsupportedWarnings(): void {
  warned.clear();
}

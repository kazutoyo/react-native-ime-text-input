/**
 * The HTML-flavoured accessibility props React Native accepts and rewrites in
 * JavaScript before they reach the view.
 *
 * SYNC: mirrors `TextInput.js` in React Native 0.86 (`nativeID={id ?? nativeID}`
 * and the `aria-*` block around `_accessibilityLabel`). A custom Fabric
 * component gets none of this for free — the mapping lives in each component's
 * JavaScript, so without it these props reach the native view under names it
 * does not know and are dropped silently.
 */
export const ARIA_PROPS = [
  'id',
  'aria-label',
  'aria-labelledby',
  'aria-hidden',
  'aria-busy',
  'aria-checked',
  'aria-disabled',
  'aria-expanded',
  'aria-selected',
] as const;

type AccessibilityState = {
  busy?: boolean;
  checked?: boolean | 'mixed';
  disabled?: boolean;
  expanded?: boolean;
  selected?: boolean;
};

export type MappedAriaProps = {
  nativeID?: string;
  accessibilityLabel?: string;
  accessibilityLabelledBy?: string;
  accessibilityElementsHidden?: boolean;
  accessibilityState?: AccessibilityState;
};

/**
 * Translates `id` and the `aria-*` props into the names the native view reads.
 *
 * Only keys that were actually given are returned, so spreading the result over
 * the remaining props never overwrites one with `undefined`.
 */
export function mapAriaProps(props: Record<string, unknown>): MappedAriaProps {
  const mapped: MappedAriaProps = {};

  const nativeID = (props.id ?? props.nativeID) as string | undefined;
  if (nativeID !== undefined) {
    mapped.nativeID = nativeID;
  }

  const label = (props['aria-label'] ?? props.accessibilityLabel) as string | undefined;
  if (label !== undefined) {
    mapped.accessibilityLabel = label;
  }

  const labelledBy = (props['aria-labelledby'] ?? props.accessibilityLabelledBy) as
    | string
    | undefined;
  if (labelledBy !== undefined) {
    mapped.accessibilityLabelledBy = labelledBy;
  }

  const hidden = (props['aria-hidden'] ?? props.accessibilityElementsHidden) as boolean | undefined;
  if (hidden !== undefined) {
    mapped.accessibilityElementsHidden = hidden;
  }

  const state = props.accessibilityState as AccessibilityState | undefined;
  const hasAriaState = ARIA_STATE.some(([aria]) => props[aria] !== undefined);

  if (state !== undefined || hasAriaState) {
    mapped.accessibilityState = Object.fromEntries(
      ARIA_STATE.map(([aria, key]) => [key, props[aria] ?? state?.[key]])
    ) as AccessibilityState;
  }

  return mapped;
}

const ARIA_STATE = [
  ['aria-busy', 'busy'],
  ['aria-checked', 'checked'],
  ['aria-disabled', 'disabled'],
  ['aria-expanded', 'expanded'],
  ['aria-selected', 'selected'],
] as const satisfies ReadonlyArray<readonly [string, keyof AccessibilityState]>;

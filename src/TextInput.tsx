import { useImperativeHandle, useRef, type ComponentRef } from 'react';
import { TextInput as RNTextInput, type TextInputProps as RNTextInputProps } from 'react-native';

import { commitCompositionOn } from './commitComposition';
import { setSelectionOn } from './setSelection';
import type { TextInputProps, TextInputRef } from './types';

/**
 * The default implementation: React Native's own `TextInput`.
 *
 * Only iOS needs replacing. The IME composition bug this library exists to fix
 * is specific to Fabric's iOS text input — Android's `EditText` and the
 * browser's `<input>` draw composition correctly — so everywhere else passes
 * straight through and keeps perfect fidelity for free. The one exception is
 * `commitComposition()`, which Android needs a native module for.
 */
export function TextInput({ ref, ...props }: TextInputProps) {
  // Derived from the component rather than named directly: under the Strict
  // TypeScript API `TextInput` used as a type is the component, not what its
  // ref holds, and the instance type behind it is not exported.
  const innerRef = useRef<ComponentRef<typeof RNTextInput>>(null);

  useImperativeHandle(
    ref,
    (): TextInputRef => ({
      focus: () => innerRef.current?.focus(),
      blur: () => innerRef.current?.blur(),
      clear: () => innerRef.current?.clear(),
      isFocused: () => innerRef.current?.isFocused() ?? false,
      setSelection: (start: number, end: number) => setSelectionOn(innerRef.current, start, end),
      // Android keeps the composition across a value update, so it is ended
      // natively; the browser ends it itself (see commitComposition.*.ts).
      commitComposition: () => commitCompositionOn(innerRef.current),
    }),
    []
  );

  // `TextInputProps` is derived from React Native's own props; `Omit` widens a
  // few handlers back to the `ViewProps` signatures that also allow `null`.
  return <RNTextInput ref={innerRef} {...(props as RNTextInputProps)} />;
}

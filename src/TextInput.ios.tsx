import { useEffect, useImperativeHandle, useLayoutEffect, useReducer, useRef } from 'react';
import { StyleSheet, type TextStyle } from 'react-native';
import TextInputState from 'react-native/Libraries/Components/TextInput/TextInputState';

import { ARIA_PROPS, mapAriaProps } from './aria';
import RNImeTextInputNativeComponent, {
  Commands,
  type RNImeTextInputViewType,
} from './RNImeTextInputNativeComponent';
import { splitStyle } from './splitStyle';
import type { TextInputProps, TextInputRef } from './types';
import { findUnsupportedProps, warnUnsupported, UNSUPPORTED_PROPS } from './unsupported';

/**
 * Builds the minimal shape of a React Native synthetic event.
 *
 * The native view sends plain values, but React Native callbacks are typed
 * around `NativeSyntheticEvent`. Consumers realistically read `nativeEvent`, so
 * that is what gets populated; the rest of the `SyntheticEvent` surface is not
 * reconstructed.
 */
function syntheticEvent<T>(nativeEvent: T) {
  return { nativeEvent } as never;
}

/**
 * Props that must not reach the native view as they are.
 *
 * `UNSUPPORTED_PROPS` do nothing on iOS but stay in the public type because
 * Android and web honour them. `ARIA_PROPS` are rewritten by `mapAriaProps`
 * into the names the view knows, so the originals would be dead weight.
 */
const NOT_FORWARDED: ReadonlySet<string> = new Set<string>([...UNSUPPORTED_PROPS, ...ARIA_PROPS]);

function forwardable(rest: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(rest)) {
    if (!NOT_FORWARDED.has(key)) {
      out[key] = value;
    }
  }
  return out;
}

/** The native side reads `''` as "not set"; the props are non-optional in C++. */
function str(value: string | undefined | null): string {
  return value ?? '';
}

// SYNC: the three maps below are copied from React Native's TextInput.js
// (0.86) so the HTML-style aliases behave identically after migration.

/** `autoComplete` → the iOS `textContentType` token the native side parses. */
const AUTO_COMPLETE_TO_TEXT_CONTENT_TYPE: Record<string, string> = {
  'additional-name': 'middleName',
  'address-line1': 'streetAddressLine1',
  'address-line2': 'streetAddressLine2',
  bday: 'birthdate',
  'bday-day': 'birthdateDay',
  'bday-month': 'birthdateMonth',
  'bday-year': 'birthdateYear',
  'cc-additional-name': 'creditCardMiddleName',
  'cc-csc': 'creditCardSecurityCode',
  'cc-exp': 'creditCardExpiration',
  'cc-exp-month': 'creditCardExpirationMonth',
  'cc-exp-year': 'creditCardExpirationYear',
  'cc-family-name': 'creditCardFamilyName',
  'cc-given-name': 'creditCardGivenName',
  'cc-name': 'creditCardName',
  'cc-number': 'creditCardNumber',
  'cc-type': 'creditCardType',
  country: 'countryName',
  'current-password': 'password',
  email: 'emailAddress',
  'family-name': 'familyName',
  'given-name': 'givenName',
  'honorific-prefix': 'namePrefix',
  'honorific-suffix': 'nameSuffix',
  name: 'name',
  'new-password': 'newPassword',
  nickname: 'nickname',
  off: 'none',
  'one-time-code': 'oneTimeCode',
  organization: 'organizationName',
  'organization-title': 'jobTitle',
  'postal-code': 'postalCode',
  'street-address': 'fullStreetAddress',
  tel: 'telephoneNumber',
  url: 'URL',
  username: 'username',
};

const INPUT_MODE_TO_KEYBOARD_TYPE: Record<string, string> = {
  decimal: 'decimal-pad',
  email: 'email-address',
  none: 'default',
  numeric: 'number-pad',
  search: 'web-search',
  tel: 'phone-pad',
  text: 'default',
  url: 'url',
};

const ENTER_KEY_HINT_TO_RETURN_KEY_TYPE: Record<string, string> = {
  done: 'done',
  enter: 'default',
  go: 'go',
  next: 'next',
  previous: 'previous',
  search: 'search',
  send: 'send',
};

/**
 * A drop-in replacement for React Native's `TextInput`, backed directly by
 * UIKit's `UITextField` and `UITextView`.
 *
 * React Native's Fabric text input rewrites `attributedText` and reapplies text
 * attributes while the user is composing, which destroys UIKit's marked-text
 * state — the underline under unconfirmed Japanese, Chinese, and Korean input
 * never renders. Owning the UIKit views avoids that code path entirely.
 */
export function TextInput(props: TextInputProps) {
  const {
    ref,
    value,
    defaultValue,
    style,
    onChange,
    onChangeText,
    onFocus,
    onBlur,
    onEndEditing,
    onSubmitEditing,
    onSelectionChange,
    onContentSizeChange,
    onKeyPress,
    selection,
    editable,
    readOnly,
    placeholder,
    placeholderTextColor,
    multiline,
    maxLength,
    autoFocus,
    selectTextOnFocus,
    clearTextOnFocus,
    submitBehavior,
    caretHidden,
    selectionColor,
    keyboardType,
    inputMode,
    returnKeyType,
    enterKeyHint,
    autoCapitalize,
    autoCorrect,
    spellCheck,
    keyboardAppearance,
    enablesReturnKeyAutomatically,
    autoComplete,
    textContentType,
    clearButtonMode,
    passwordRules,
    smartInsertDelete,
    contextMenuHidden,
    inputAccessoryViewButtonLabel,
    inputAccessoryViewID,
    allowFontScaling,
    maxFontSizeMultiplier,
    textAlign,
    testID,
    ...rest
  } = props;

  if (__DEV__) {
    warnUnsupported('prop', findUnsupportedProps(props as Record<string, unknown>));
  }

  const nativeRef = useRef<React.ComponentRef<RNImeTextInputViewType>>(null);
  const isFocusedRef = useRef(false);
  // Captured once: React Native ignores later `defaultValue` changes too.
  const initialTextRef = useRef(value ?? defaultValue ?? '');
  // The last defined `value`. When a parent goes controlled → uncontrolled
  // (`value` becomes undefined), the `text` prop must not change — falling back
  // to the mount-time initial would wipe what the user typed. React Native
  // leaves the native text untouched in that transition.
  const lastValueRef = useRef(value);
  if (value !== undefined) {
    lastValueRef.current = value;
  }
  // The eventCount from the last change event JS processed, echoed to native so
  // a value that predates the user's latest keystroke is never applied.
  const lastEventCountRef = useRef(0);

  // Bumped after every native edit. React Native reverts a controlled field
  // when the parent refuses the change, but if `value` never changes then the
  // `text` prop never changes either and nothing would be sent down. This
  // always changes, so the native side gets a chance to re-assert `value`.
  const [textRevision, bumpRevision] = useReducer((n: number) => n + 1, 0);

  useImperativeHandle(
    ref,
    (): TextInputRef => ({
      focus: () => {
        if (nativeRef.current) Commands.focus(nativeRef.current);
      },
      blur: () => {
        if (nativeRef.current) Commands.blur(nativeRef.current);
      },
      clear: () => {
        if (nativeRef.current) Commands.clear(nativeRef.current);
      },
      isFocused: () => isFocusedRef.current,
      setSelection: (start: number, end: number) => {
        if (nativeRef.current) Commands.setSelection(nativeRef.current, start, end);
      },
      commitComposition: () => {
        if (nativeRef.current) Commands.commitComposition(nativeRef.current);
      },
    }),
    []
  );

  // Join React Native's focus registry. `ScrollView` asks it whether a tap
  // landed on a text input (`keyboardShouldPersistTaps`) and `Keyboard.dismiss()`
  // asks it who to blur; an input it has never heard of makes both do nothing at
  // all, with no error to notice. Registering has to happen in a layout effect
  // rather than on render so the native view exists to be registered.
  useLayoutEffect(() => {
    const view = nativeRef.current;
    if (!view) {
      return;
    }
    TextInputState.registerInput(view);
    return () => {
      TextInputState.unregisterInput(view);
      // A view that is going away cannot be blurred, but leaving it on record as
      // focused would have the next `Keyboard.dismiss()` aim at nothing. UIKit
      // resigns first responder by itself when the view leaves the hierarchy.
      if (TextInputState.currentlyFocusedInput() === view) {
        TextInputState.blurInput(view);
      }
    };
  }, []);

  const selectionStart = selection?.start;
  const selectionEnd = selection?.end;
  useEffect(() => {
    if (selectionStart === undefined || !nativeRef.current) {
      return;
    }
    Commands.setSelection(nativeRef.current, selectionStart, selectionEnd ?? selectionStart);
  }, [selectionStart, selectionEnd]);

  const flat = (StyleSheet.flatten(style) ?? {}) as TextStyle;
  const { viewStyle, text: textStyle, unsupported: unsupportedStyle } = splitStyle(flat);

  if (__DEV__) {
    warnUnsupported('style', unsupportedStyle);
  }

  const isEditable = editable ?? (readOnly === undefined ? true : !readOnly);
  const shadowOffset = textStyle.textShadowOffset;

  return (
    <RNImeTextInputNativeComponent
      {...forwardable(rest as Record<string, unknown>)}
      {...mapAriaProps(props as Record<string, unknown>)}
      ref={nativeRef}
      style={viewStyle}
      // `value` is what makes the field controlled; without it the revision
      // never advances, so the initial text is applied once and the native view
      // owns its content from then on — matching React Native.
      text={value ?? lastValueRef.current ?? initialTextRef.current}
      textRevision={textRevision}
      mostRecentEventCount={lastEventCountRef.current}
      placeholder={str(placeholder)}
      placeholderTextColor={placeholderTextColor ?? undefined}
      multiline={multiline ?? false}
      maxLength={maxLength ?? 0}
      editable={isEditable}
      autoFocus={autoFocus ?? false}
      selectTextOnFocus={selectTextOnFocus ?? false}
      clearTextOnFocus={clearTextOnFocus ?? false}
      submitBehavior={str(submitBehavior)}
      caretHidden={caretHidden ?? false}
      contextMenuHidden={contextMenuHidden ?? false}
      selectionColor={selectionColor ?? undefined}
      keyboardType={str(keyboardType ?? (inputMode ? INPUT_MODE_TO_KEYBOARD_TYPE[inputMode] : undefined))}
      returnKeyType={str(
        returnKeyType ?? (enterKeyHint ? ENTER_KEY_HINT_TO_RETURN_KEY_TYPE[enterKeyHint] : undefined)
      )}
      autoCapitalize={str(autoCapitalize)}
      autoCorrect={autoCorrect ?? true}
      spellCheck={spellCheck === undefined ? 'auto' : spellCheck ? 'yes' : 'no'}
      keyboardAppearance={str(keyboardAppearance)}
      enablesReturnKeyAutomatically={enablesReturnKeyAutomatically ?? false}
      textContentType={str(
        textContentType ?? (autoComplete ? AUTO_COMPLETE_TO_TEXT_CONTENT_TYPE[autoComplete] : undefined)
      )}
      clearButtonMode={str(clearButtonMode)}
      inputAccessoryViewButtonLabel={str(inputAccessoryViewButtonLabel)}
      inputAccessoryViewID={str(inputAccessoryViewID)}
      passwordRules={str(passwordRules)}
      // Tri-state for the same reason as `spellCheck`: UIKit's default is not
      // the same as an explicit "yes", and a bare boolean cannot say "not set".
      smartInsertDelete={
        smartInsertDelete === undefined ? 'auto' : smartInsertDelete ? 'yes' : 'no'
      }
      textAlign={str(textAlign ?? textStyle.textAlign)}
      // React Native's default is `true`: text follows the system text size
      // setting unless a component opts out.
      allowFontScaling={allowFontScaling ?? true}
      // 0 means no cap, matching React Native — anything below 1 is ignored
      // natively rather than shrinking the text.
      maxFontSizeMultiplier={maxFontSizeMultiplier ?? 0}
      fontSize={textStyle.fontSize ?? 17}
      fontWeight={str(textStyle.fontWeight)}
      fontFamily={str(textStyle.fontFamily)}
      fontStyle={str(textStyle.fontStyle)}
      color={textStyle.color ?? undefined}
      lineHeight={textStyle.lineHeight ?? 0}
      letterSpacing={textStyle.letterSpacing ?? 0}
      textDecorationLine={str(textStyle.textDecorationLine)}
      textDecorationColor={textStyle.textDecorationColor ?? undefined}
      textDecorationStyle={str(textStyle.textDecorationStyle)}
      textShadowColor={textStyle.textShadowColor ?? undefined}
      textShadowOffsetWidth={shadowOffset?.width ?? 0}
      textShadowOffsetHeight={shadowOffset?.height ?? 0}
      textShadowRadius={textStyle.textShadowRadius ?? 0}
      writingDirection={str(textStyle.writingDirection)}
      testID={testID}
      onChangeText={(event) => {
        const next = event.nativeEvent.text;
        lastEventCountRef.current = event.nativeEvent.eventCount;
        onChangeText?.(next);
        onChange?.(syntheticEvent({ text: next, eventCount: event.nativeEvent.eventCount, target: 0 }));
        if (value !== undefined) {
          bumpRevision();
        }
      }}
      onInputFocus={(event) => {
        isFocusedRef.current = true;
        TextInputState.focusInput(nativeRef.current);
        onFocus?.(syntheticEvent({ text: event.nativeEvent.text, eventCount: 0, target: 0 }));
      }}
      onInputBlur={(event) => {
        isFocusedRef.current = false;
        TextInputState.blurInput(nativeRef.current);
        const text = event.nativeEvent.text;
        onBlur?.(syntheticEvent({ text, eventCount: 0, target: 0 }));
        onEndEditing?.(syntheticEvent({ text, eventCount: 0, target: 0 }));
      }}
      // The bodies below are braced rather than expression-returned on purpose:
      // React Native types a `TextInput` callback as returning `mixed`, which
      // arrives here as `unknown`, while a codegen `DirectEventHandler` must
      // return `void`. Handing the callback's result straight back would leak
      // that `unknown` into the native prop.
      onSubmit={
        onSubmitEditing
          ? (event) => {
              onSubmitEditing(
                syntheticEvent({ text: event.nativeEvent.text, eventCount: 0, target: 0 })
              );
            }
          : undefined
      }
      onSelectionChange={
        onSelectionChange
          ? (event) => {
              onSelectionChange(
                syntheticEvent({
                  selection: { start: event.nativeEvent.start, end: event.nativeEvent.end },
                  target: 0,
                })
              );
            }
          : undefined
      }
      onContentSizeChange={
        onContentSizeChange
          ? (event) => {
              onContentSizeChange(
                syntheticEvent({
                  contentSize: {
                    width: event.nativeEvent.width,
                    height: event.nativeEvent.height,
                  },
                  target: 0,
                })
              );
            }
          : undefined
      }
      onInputKeyPress={
        onKeyPress
          ? (event) => {
              onKeyPress(syntheticEvent({ key: event.nativeEvent.key }));
            }
          : undefined
      }
    />
  );
}

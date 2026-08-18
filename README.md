# react-native-ime-text-input

[![npm](https://img.shields.io/npm/v/react-native-ime-text-input)](https://www.npmjs.com/package/react-native-ime-text-input)
[![CI](https://github.com/kazutoyo/react-native-ime-text-input/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/kazutoyo/react-native-ime-text-input/actions/workflows/ci.yml)
[![License](https://img.shields.io/npm/l/react-native-ime-text-input)](LICENSE)

**English** | [日本語](README.ja.md)

A drop-in replacement for React Native's `TextInput` that restores the IME composition underline on iOS.

```diff
- import { TextInput } from 'react-native';
+ import { TextInput } from 'react-native-ime-text-input';
```

## The problem

On iOS with the New Architecture, **the underline under unconfirmed Japanese, Chinese, and Korean text never renders** — there is no way to tell text you are still converting from text you have committed.

React Native's Fabric text input destroys UIKit's marked-text state while a conversion is open; [facebook/react-native#56082](https://github.com/facebook/react-native/pull/56082) lists the causes. That pull request is still open and [issue #55257](https://github.com/facebook/react-native/issues/55257) was auto-closed as stale rather than fixed, so the bug is live in React Native 0.86 / Expo SDK 57 — and Expo SDK 55+ forces the New Architecture, so turning it off is not an escape either.

This library owns the UIKit views instead, and never touches the text buffer while a conversion is open.

| Platform | Renders | |
| --- | --- | --- |
| iOS | `UITextField` / `UITextView` when `multiline` | Avoids the Fabric path entirely |
| Android | React Native's `TextInput` | `EditText` was never affected |
| Web | React Native's `TextInput` | The browser handles composition itself |

Only iOS is replaced, so the other platforms keep React Native's behaviour exactly — there is nothing that can diverge.

## Install

Requires **React Native 0.81+ with the New Architecture**. The package ships native code, so it needs a real build and does not run in Expo Go.

```sh
# bare React Native
npm install react-native-ime-text-input && cd ios && pod install

# Expo
npx expo install react-native-ime-text-input && npx expo run:ios
```

## Usage

```tsx
import { TextInput } from 'react-native-ime-text-input';

const [text, setText] = useState('');

<TextInput value={text} onChangeText={setText} placeholder="Type here" />;
```

A chat composer needs no height state, no `onContentSizeChange`, and no library-specific prop. The field grows with its text, `maxHeight` caps it, and past the cap the `UITextView` scrolls inside:

```tsx
<TextInput
  value={text}
  onChangeText={setText}
  style={{ minHeight: 24, maxHeight: 110, fontSize: 17 }}
  multiline
/>
```

## API

**Props** — everything React Native's `TextInput` accepts. The type is React Native's own apart from `ref`, so replacing the import never produces a type error. A few props do nothing on iOS; see [Differences](#differences-from-react-natives-textinput).

**Style** — a normal `TextStyle`. Box and layout properties are drawn by the native view, typography is forwarded to the text view — including the ones that become `NSAttributedString` attributes: `fontSize`, `fontWeight` (numeric and named, `'semibold'` and friends), `fontFamily`, `fontStyle`, `color`, `textAlign`, `lineHeight`, `letterSpacing`, `textDecorationLine` / `Color` / `Style`, `textShadowColor` / `Offset` / `Radius`, `writingDirection`.

**Ref**

```ts
type TextInputRef = {
  focus: () => void;
  blur: () => void;
  clear: () => void;
  isFocused: () => boolean;
  setSelection: (start: number, end: number) => void;
  commitComposition: () => void; // iOS only; a no-op elsewhere
};
```

`commitComposition()` is the one method React Native's `TextInput` has no equivalent for. It confirms an in-progress IME conversion, so that a value set right after it replaces the composed text instead of being queued behind it. See [Inserting text while the user is composing](#inserting-text-while-the-user-is-composing).

## Differences from React Native's `TextInput`

### Composition is protected

The places where React Native writes mid-conversion and cuts it short. These are the only deliberate changes in behaviour, and the reason to use this at all.

| | React Native | Here |
| --- | --- | --- |
| Writing `value` mid-conversion | Applied immediately, cancelling the conversion | Held until the conversion commits, then applied |
| `maxLength` mid-conversion | Truncates intermediate output | Enforced only once the text commits |
| Text attributes (`lineHeight`, `letterSpacing`, …) mid-conversion | Reapplied, clearing marked text | Held until the conversion commits |

Rewriting the text inside `onChangeText` and feeding it back through `value` — input masking, forced upper case, character filtering — still cancels the conversion. It is deferred until the conversion commits rather than cut off mid-word, but not avoided. Prefer applying such transforms on submit.

### Inserting text while the user is composing

Holding a value back is right for a controlled `value` echoing what the user is typing, and wrong for an insertion the user just asked for. An emoji picker, a mention bar or a formatting button tapped mid-conversion would appear to do nothing, and then overwrite the conversion result when it commits — the held value was computed from the unconfirmed reading.

Only the caller knows which of the two it is about to send, so it says so:

```tsx
const insertEmoji = (emoji: string) => {
  ref.current?.commitComposition();
  setValue((current) => current + emoji);
};
```

The conversion is confirmed as it stands, the same as tapping elsewhere in the field would — it does not pick a candidate. React Native's `TextInput` has no way to do this on iOS at all: writing `value` mid-conversion is what clears the composition there, so the insertion lands but the underline goes with it.

Nothing to do on Android and web — their IMEs commit on their own when the value is replaced — and the method is a no-op there so the same code runs everywhere.

### Ignored on iOS

It behaves like React Native's `TextInput` for the most part, but a few props and style properties are not supported. Only iOS is replaced, so these work normally on Android and web.

Passing one on iOS ignores the value and warns once per prop name in `__DEV__`.

**Props.** `blurOnSubmit` (use `submitBehavior`), `dataDetectorTypes`, `disableFullscreenUI`, `importantForAutofill`, `inlineImageLeft`, `inlineImagePadding`, `lineBreakStrategyIOS`, `onScroll`, `rejectResponderTermination`, `returnKeyLabel`, `scrollEnabled`, `showSoftInputOnFocus`, `textBreakStrategy`, `underlineColorAndroid`

Some of that list is Android-only or deprecated, so React Native's own iOS implementation ignores it too and nothing is lost relative to it: `blurOnSubmit`, `disableFullscreenUI`, `importantForAutofill`, `inlineImageLeft`, `inlineImagePadding`, `returnKeyLabel`, `textBreakStrategy`, `underlineColorAndroid`.

The rest React Native core does implement on iOS, and they are simply not implemented here yet: `dataDetectorTypes`, `lineBreakStrategyIOS`, `onScroll`, `rejectResponderTermination`, `scrollEnabled`, `showSoftInputOnFocus`. The last is easy to misjudge — React Native's *types* list it under Android, but its Fabric iOS view implements it.

**Style properties.** `textTransform`, `fontVariant`, `verticalAlign`, `textAlignVertical`, `includeFontPadding`

`setNativeProps()` and the `measure*` family are absent from `TextInputRef` on every platform, so those are type errors — the ref type is the one thing that is ours rather than React Native's.

### Other differences

| | React Native | Here |
| --- | --- | --- |
| Callback events | Full `SyntheticEvent` | Only `nativeEvent` is populated; `target` is `0`. Change events carry a real `eventCount` |
| `ref.clear()` | Does not fire `onChangeText` | Fires it, so a controlled parent stays in sync |
| `ref.isFocused()` | Queries the native view | Tracked in JavaScript from focus/blur events |
| `ref.commitComposition()` | Absent | Confirms an open IME conversion |
| `onEndEditing` | Fires when editing ends | Fires on blur, which is when UIKit reports it |

Unchanged, because these are what a replacement usually gets wrong: there is no extra view in the tree — the component *is* the native view, so `flex`, `margin` and sibling layout behave exactly as before; and `multiline` self-sizing matches React Native's, through the same mechanism.

Android and web render React Native's `TextInput` unchanged. The one piece of library code there is the ref wrapper, so `TextInputRef` is the only place those platforms can diverge — on web, `setSelection()` falls through to the DOM's `setSelectionRange`, because react-native-web's ref exposes only `clear` and `isFocused`.

## How it works

The UIKit views are ours, so React Native's Fabric text input is out of the picture on iOS entirely. Three rules then keep the composition intact.

**1. The text buffer is never rewritten while `markedTextRange` is set.**
Rewriting it is what clears UIKit's marked-text state. A value JavaScript wants is held and applied the moment the conversion commits; `maxLength` follows the same rule.

**2. Text attributes are never written mid-conversion either.**
That is what makes `lineHeight`, `letterSpacing`, italics and underlines safe to support. Updates that arrive without a prop change — a system text size change, say — go through the same path.

**3. No-op `NSShadow` and transparent `NSBackgroundColor` entries are never emitted.**
UIKit silently stops drawing the underline when either is present. It is the subtlest of the upstream causes.

## Verified

Checked on an iPhone 17 Pro simulator (iOS 26.5, React Native 0.86.2) with the Japanese kana keyboard:

- Composition underline renders, during and across conversions
- Controlled `value` survives composition; a refused edit reverts once the conversion commits
- `focus()` / `clear()` / `maxLength` / text attributes behave as documented
- A `multiline` field grows 20 → 61 → 81 → 122px with its content and stops at `maxHeight`
- Fields laid out off-screen in a `ScrollView` render and hit-test in the right place

Verified again on React Native 0.81.6 / Expo SDK 54, the floor of the supported
range: the codegen view config is generated, the pod builds, and the native
tests pass. 0.81 is the floor because `CodegenTypes` only became a namespace
React Native's codegen understands in 0.80, and only reached its public types in
0.81; below that the component spec cannot be expressed as it is written here.

Also verified in a production app on React Native 0.85.3 / Expo SDK 56 — composition underline, `ref.setSelection()`, multiline resizing, `selection` / `onSelectionChange` / `cursorColor` / `selectionColor`.

Platform resolution is verified by bundling: the Android bundle contains `src/TextInput.tsx` and zero references to the native component, and CI bundles a plain consumer app against the packed tarball so the published layout is exercised, not just the example's aliased one. Android has not been run on a device.

## Development

```sh
npm install        # library + example app (npm workspaces)
npm test           # unit and component tests
npm run typecheck
npm run build

cd example && npx expo run:ios
npm run test:native  # XCTest, through the pod's test spec
npm run test:e2e     # Maestro flows against that build
```

`npm test` covers the pure functions and, mirroring React Native's own
`TextInput-itest.js`, what the adapter sends to the native view and which
commands it dispatches.

`npm run test:native` runs the XCTest bundle CocoaPods builds from the
podspec's test spec. It covers the attribute dictionary — including the no-op
`NSShadow` and transparent `NSBackgroundColor` that stop UIKit drawing the
underline — and the marked-text rules themselves: a conversion is staged with
`setMarkedText:selectedRange:`, the same call the keyboard makes, so composition
can be asserted without one.

`npm run test:e2e` drives the example app on a booted simulator. It covers
focus, typing, the controlled revert, `maxLength` and self-sizing — **not the
composition underline**, which is the one thing it cannot reach: Maestro's
`inputText` bypasses the IME, so conversion has to be checked by hand with a
Japanese keyboard.

The example resolves `react-native-ime-text-input` straight to `src` (see `example/metro.config.js`), so JavaScript edits appear without a rebuild. Native changes — or changes to the codegen spec — need `npx expo run:ios` again.

```
src/
  RNImeTextInputNativeComponent.ts  codegen spec — the source of truth for props, events, commands
  TextInput.ios.tsx                 React Native props → native props
  TextInput.tsx                     Android / web — passes through to React Native
  splitStyle.ts                     style → view style + typography props
  unsupported.ts                    props ignored on iOS, warned once each
ios/
  RNImeTextInput.h/.mm              RCTViewComponentView owning UITextField / UITextView
  RNImeTextInputAttributes.h/.mm    the attribute dictionary
  RNImeTextInputState.h             Fabric state: the size the text wants
  RNImeTextInputShadowNode.h/.mm    measureContent, reporting that size
  RNImeTextInputComponentDescriptor.h
```

## License

MIT

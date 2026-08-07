# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-08-08

### Fixed

- The placeholder is now drawn with the field's full text attributes, not just
  its font. `lineHeight` and `letterSpacing` never reached it, so a placeholder
  laid out on the font's own line height sat higher than the text that replaced
  it — with `fontSize: 14` and `lineHeight: 20`, 3.3pt higher — and the line
  visibly dropped the moment the first character was typed. React Native builds
  its placeholder the same way this now does, from the default text attributes
  with the placeholder colour swapped in.

## [0.3.0] - 2026-08-06

### Added

- `clearButtonMode`, `passwordRules` and `smartInsertDelete` now reach UIKit on
  iOS. `clearButtonMode` was previously listed as unsupported on the grounds
  that UIKit had no equivalent, which was wrong — `UITextField.clearButtonMode`
  is exactly it, and React Native core sets the same property.
- `contextMenuHidden` now suppresses the cut/copy/paste menu on iOS. There is no
  UIKit property for it, so the backing views are subclassed to override
  `canPerformAction:` and, from iOS 17, `buildMenuWithBuilder:` — the same two
  halves React Native core overrides.
- A number pad now gets the same default toolbar React Native gives it. A
  `number-pad`, `phone-pad`, `decimal-pad` or ASCII-capable number pad has no
  return key, so a field using one could not be dismissed from the keyboard at
  all. The toolbar appears when `returnKeyType` names a key or the new
  `inputAccessoryViewButtonLabel` prop gives it a title, and its button submits
  and blurs exactly as the return key does.
- `inputAccessoryViewID` now connects a field to React Native's
  `InputAccessoryView`. Nothing reads the prop back: React Native's component
  walks the window for a view answering to `inputAccessoryViewID` and
  `setInputAccessoryView:` and assigns itself, so carrying the id is the whole
  contract. When one is set, the default number-pad toolbar steps aside rather
  than taking the slot from the accessory content — and a toolbar drawn before
  the id arrived is taken back off, so the wrong bar is never left behind.

### Fixed

- Text now follows the system text size setting, as React Native's `TextInput`
  does. `allowFontScaling` defaults to `true` in React Native, so this diverged
  at the default: nobody had to pass anything to get the old behaviour, and no
  warning fired. Anyone using a larger Text Size saw a field that ignored it.
  `allowFontScaling` and `maxFontSizeMultiplier` are now honoured, `lineHeight`
  scales alongside the font and letter spacing does not — matching core — and a
  text size change that arrives mid-conversion is held back like any other
  attribute change rather than dropping the composition underline.

### Changed

- The "ignored on iOS" documentation no longer claims every prop in that list
  lacks a UIKit equivalent. Six of them — `dataDetectorTypes`,
  `lineBreakStrategyIOS`, `onScroll`, `rejectResponderTermination`,
  `scrollEnabled` and `showSoftInputOnFocus` — are implemented by React Native
  core on iOS and simply are not implemented here yet. `showSoftInputOnFocus` is
  the easiest to misjudge: React Native's types put it under Android, but its
  Fabric iOS view implements it by swapping `inputView` for an empty one.
- The spec/native sync check strips comments before searching. A prop mentioned
  only in prose — including one documented as *not* supported — satisfied the
  search and passed vacuously, which is exactly what happened to
  `inputAccessoryViewID` before this change.

## [0.2.1] - 2026-08-06

### Fixed

- `testID` and the accessibility props never reached the UIKit view.
  `RCTViewComponentView` writes them to `self.accessibilityElement`, which
  defaults to the host view — not the `UITextField` / `UITextView` that
  VoiceOver and automation drivers actually see. Maestro, Detox and XCUITest
  could not target the field at all, and VoiceOver read no label. React Native's
  own text input overrides this the same way.

### Changed

- `peerDependencies` now allows **React Native 0.81+**, down from 0.85. Verified
  on 0.81.6 / Expo SDK 54: the codegen view config is generated, the pod builds,
  and the native tests pass. 0.81 is the floor because `CodegenTypes` only
  became a namespace React Native's codegen understands in 0.80, and only
  reached its public types in 0.81.

## [0.2.0] - 2026-08-05

### Fixed

- **The published package could not be bundled.** `main` pointed at `build/`,
  where tsc had stripped the type argument of
  `codegenNativeComponent<NativeProps>` that the codegen babel plugin builds the
  static view config from, so any consumer failed with `Could not find component
  config for native component`. A `react-native` field now points Metro at the
  typed source. Reported by a consumer app; the example resolved the library to
  `src`, so the published layout had never been exercised.
- `ref.setSelection()` threw a `TypeError` on web. react-native-web's ref
  exposes only `clear` and `isFocused`, so the call now falls through to the
  DOM's `setSelectionRange`.

### Added

- `id` is mapped to `nativeID`, and `aria-label`, `aria-labelledby`,
  `aria-hidden` and the `aria-*` state props to their `accessibility*`
  equivalents, matching what React Native's `TextInput` does in JavaScript.
  Without it these reached the native view under names it does not know.

### Changed

- `peerDependencies` allows React Native 0.85+, down from 0.86.
- Props that do nothing on iOS are no longer removed from the prop type. A
  cross-platform component should not fail to compile over a prop that is valid
  on Android or web; iOS drops the value and warns once per name in `__DEV__`
  instead.

## [0.1.0] - 2026-08-05

Initial release. A drop-in replacement for React Native's `TextInput` that
restores the IME composition underline on iOS by owning the UIKit views, with
React Native's own `TextInput` on Android and web.

[Unreleased]: https://github.com/kazutoyo/react-native-ime-text-input/compare/0.4.0...HEAD
[0.4.0]: https://github.com/kazutoyo/react-native-ime-text-input/compare/0.3.0...0.4.0
[0.3.0]: https://github.com/kazutoyo/react-native-ime-text-input/compare/0.2.1...0.3.0
[0.2.1]: https://github.com/kazutoyo/react-native-ime-text-input/compare/0.2.0...0.2.1
[0.2.0]: https://github.com/kazutoyo/react-native-ime-text-input/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/kazutoyo/react-native-ime-text-input/releases/tag/0.1.0

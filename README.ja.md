# react-native-ime-text-input

[English](README.md) | **日本語**

iOS で IME の未確定文字に下線が出ない問題を直した、React Native の `TextInput` をそのまま置き換えられるライブラリです。

```diff
- import { TextInput } from 'react-native';
+ import { TextInput } from 'react-native-ime-text-input';
```

## 問題

New Architecture の iOS では、**日本語・中国語・韓国語の未確定文字に下線が描画されません**。変換中の文字と確定済みの文字を見分けられなくなります。

原因は、React Native の Fabric テキスト入力が変換中に UIKit の marked text を壊してしまうことです。詳細は [facebook/react-native#56082](https://github.com/facebook/react-native/pull/56082) にまとまっています。この PR は今も open のままで、[issue #55257](https://github.com/facebook/react-native/issues/55257) は修正されないまま stale で自動クローズされました。
そのため React Native 0.86 / Expo SDK 57 でもバグは残っています。Expo SDK 55 以降は New Architecture が強制なので、オフにして避けることもできません。

本ライブラリは UIKit のビューを自前で持ち、変換中はテキストバッファに一切触れません。

| プラットフォーム | 描画するもの | |
| --- | --- | --- |
| iOS | `UITextField` / `multiline` なら `UITextView` | Fabric の経路を通らない |
| Android | React Native の `TextInput` | `EditText` は元から影響なし |
| Web | React Native の `TextInput` | 変換はブラウザが扱う |

置き換えるのは iOS だけです。他のプラットフォームは React Native の実装をそのまま使うので、挙動がずれる余地がありません。

## インストール

**React Native 0.85 以降 + New Architecture** が必要です。ネイティブコードを含むため、Expo Go では動きません（development build が必要です）。

```sh
# bare React Native
npm install react-native-ime-text-input && cd ios && pod install

# Expo
npx expo install react-native-ime-text-input && npx expo run:ios
```

## 使い方

```tsx
import { TextInput } from 'react-native-ime-text-input';

const [text, setText] = useState('');

<TextInput value={text} onChangeText={setText} placeholder="入力してください" />;
```

チャットの入力欄を作るのに、高さの state も `onContentSizeChange` も、ライブラリ独自の prop も要りません。テキストに応じて伸び、`maxHeight` で止まり、それ以降は `UITextView` の中がスクロールします。

```tsx
<TextInput
  value={text}
  onChangeText={setText}
  style={{ minHeight: 24, maxHeight: 110, fontSize: 17 }}
  multiline
/>
```

## API

**props** — React Native の `TextInput` が受け取るもの一式です。型は ref を除いて React Native のものそのままなので、import を差し替えても型エラーは出ません。一部の prop は iOS では効きません（[差分](#標準の-textinput-との差分)を参照）。

**style** — 普通の `TextStyle` です。ボックス系・レイアウト系はネイティブビューが描画し、タイポグラフィはテキストビューへ渡します。`NSAttributedString` の属性になるものにも対応しています：`fontSize` / `fontWeight`（数値と `'semibold'` などの名前付きの両方）/ `fontFamily` / `fontStyle` / `color` / `textAlign` / `lineHeight` / `letterSpacing` / `textDecorationLine`・`Color`・`Style` / `textShadowColor`・`Offset`・`Radius` / `writingDirection`

**ref**

```ts
type TextInputRef = {
  focus: () => void;
  blur: () => void;
  clear: () => void;
  isFocused: () => boolean;
  setSelection: (start: number, end: number) => void;
};
```

## 標準の `TextInput` との差分

### 変換中の状態を壊さない

React Native の `TextInput` が変換中に書き込みを行い、変換を打ち切ってしまう箇所です。
ここだけは修正のために意図的に挙動を変えています。

| | React Native | 本ライブラリ |
| --- | --- | --- |
| 変換中の `value` 書き込み | 即座に適用し、変換を打ち切る | 変換確定まで保留し、その後で適用 |
| 変換中の `maxLength` | 変換途中の文字列を切り詰める | 確定してから適用 |
| 変換中のテキスト属性（`lineHeight` / `letterSpacing` など） | 再適用して marked text を消す | 変換確定まで保留 |

ただし、入力マスクや文字のフィルタのように `onChangeText` でテキストを加工して `value` に戻す実装は、これまで通り変換を打ち切ります。
変換の途中で切られる代わりに確定まで遅延されるだけで、回避できるわけではありません。この種の加工は送信時に行うことをおすすめします。

### iOS で効かない props とスタイルプロパティ

基本的には React Native の `TextInput` と同じように使えますが、一部の props とスタイルプロパティはサポートしていません。
置き換えているのは iOS だけなので、以下は Android と web では通常どおり動きます。

これらを iOS で指定したときは値を無視し、`__DEV__` で prop 名ごとに1回だけ警告します。

**props。** `allowFontScaling` / `blurOnSubmit`（`submitBehavior` を使ってください）/ `clearButtonMode` / `contextMenuHidden` / `dataDetectorTypes` / `disableFullscreenUI` / `importantForAutofill` / `inlineImageLeft` / `inlineImagePadding` / `inputAccessoryViewID` / `lineBreakStrategyIOS` / `maxFontSizeMultiplier` / `onScroll` / `rejectResponderTermination` / `returnKeyLabel` / `scrollEnabled` / `showSoftInputOnFocus` / `textBreakStrategy` / `underlineColorAndroid`

**スタイルプロパティ。** `textTransform` / `fontVariant` / `verticalAlign` / `textAlignVertical` / `includeFontPadding`

`setNativeProps()` と `measure*` 系は `TextInputRef` に用意していないため、どのプラットフォームでも型エラーになります。ref の型だけは React Native のものではなく本ライブラリ独自のものです。

### その他の差分

| | React Native | 本ライブラリ |
| --- | --- | --- |
| コールバックのイベント | 完全な `SyntheticEvent` | `nativeEvent` のみ。`target` は `0`。変更イベントには実際の `eventCount` が入る |
| `ref.clear()` | `onChangeText` を発火しない | 発火する。controlled な親と同期を保つため |
| `ref.isFocused()` | ネイティブビューに問い合わせる | focus / blur イベントから JavaScript 側で追跡 |
| `onEndEditing` | 編集終了時に発火 | blur 時に発火（UIKit が編集終了を伝えてくるのがこのタイミングのため） |

置き換え実装が壊しがちな点は、そのまま維持しています。ツリーに余分な View は入らないので（コンポーネント自体がネイティブビューです）、`flex` / `margin` / 兄弟要素のレイアウトは従来通りです。`multiline` の自動サイズも React Native と同じ仕組みで同じように動きます。

Android と web は React Native の `TextInput` をそのまま描画します。唯一ライブラリ自身のコードなのが ref のラッパーで、`TextInputRef` だけがこの2つのプラットフォームで乖離しうる箇所です。web では react-native-web の ref が `clear` と `isFocused` しか持たないため、`setSelection()` は DOM の `setSelectionRange` に落ちます。

## 仕組み

UIKit のビューを自前で持っているので、iOS では React Native の Fabric テキスト入力を通りません。そのうえで変換中の状態を守るために3つのルールを守っています。`markedTextRange` がある間はテキストバッファを書き換えません（これが UIKit の marked text を消す原因なので、JavaScript が渡したい値は変換が確定した瞬間に適用します。`maxLength` も同じです）。変換中はテキスト属性も書き込みません（`lineHeight` / `letterSpacing` / 斜体 / 下線に対応できるのはこのためです）。そして、実質何もしない `NSShadow` や透明な `NSBackgroundColor` を出力しません — どちらかがあると UIKit は下線の描画を黙ってやめてしまう、上流の原因の中でも最も気づきにくいものです。

## 検証済み

iPhone 17 Pro シミュレータ（iOS 26.5 / React Native 0.86.2）と日本語かなキーボードで確認しています。

- 未確定文字の下線が、変換中も再変換をまたいでも描画される
- controlled な `value` が変換を壊さず、拒否された編集は確定後に巻き戻る
- `focus()` / `clear()` / `maxLength` / テキスト属性がドキュメント通りに動く
- `multiline` が内容に応じて 20 → 61 → 81 → 122px と伸び、`maxHeight` で止まる
- `ScrollView` 内で画面外にレイアウトされた入力欄が、正しい位置に描画されタップに反応する

React Native 0.85.3 / Expo SDK 56 の実アプリでも確認されています（変換下線、`ref.setSelection()`、multiline の自動リサイズ、`selection` / `onSelectionChange` / `cursorColor` / `selectionColor`）。

プラットフォームごとのファイル解決はバンドルで確認しています。Android バンドルには `src/TextInput.tsx` が含まれ、ネイティブコンポーネントへの参照は0件です。また CI が、pack した tarball を素の consumer アプリに install してバンドルするので、example の alias 経由ではなく publish される形が検証されます。Android は実機での動作確認をしていません。

## 開発

```sh
npm install        # ライブラリ + example アプリ（npm workspaces）
npm test           # ユニットテストとコンポーネントテスト
npm run typecheck
npm run build

cd example && npx expo run:ios
npm run test:e2e   # そのビルドに対して Maestro を実行
```

`npm test` は純関数に加えて、React Native 自身の `TextInput-itest.js` と同じ
観点で、アダプタがネイティブビューに渡す props と発行するコマンドを検証します。

`npm run test:e2e` は起動中のシミュレータで example アプリを操作します。
フォーカス・入力・controlled の巻き戻し・`maxLength`・自動リサイズが対象で、
**変換下線だけは対象外**です。Maestro の `inputText` は IME を経由しないため、
変換の確認は日本語キーボードで手動で行う必要があります。

example は `react-native-ime-text-input` を直接 `src` に解決します（`example/metro.config.js`）。JavaScript の変更は再ビルドなしで反映されます。ネイティブと codegen spec の変更は `npx expo run:ios` をやり直す必要があります。

```
src/
  RNImeTextInputNativeComponent.ts  codegen spec — props / イベント / コマンドの source of truth
  TextInput.ios.tsx                 React Native の props → ネイティブ props
  TextInput.tsx                     Android / web — React Native へパススルー
  splitStyle.ts                     style → ビューのスタイル + タイポグラフィ props
  unsupported.ts                    iOS で無視する props（1回ずつ警告）
ios/
  RNImeTextInput.h/.mm              UITextField / UITextView を持つ RCTViewComponentView
  RNImeTextInputAttributes.h/.mm    属性辞書
  RNImeTextInputState.h             Fabric state: テキストが必要とするサイズ
  RNImeTextInputShadowNode.h/.mm    measureContent でそのサイズを報告
  RNImeTextInputComponentDescriptor.h
```

## ライセンス

MIT

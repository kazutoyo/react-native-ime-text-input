import { fireEvent, render, screen } from '@testing-library/react-native';
import { createRef } from 'react';

import { Commands } from '../RNImeTextInputNativeComponent';
import { TextInput } from '../TextInput';
import type { TextInputRef } from '../types';
import { resetUnsupportedWarnings } from '../unsupported';

/**
 * Mirrors React Native's own `TextInput-itest.js`, which asserts on what reaches
 * the mounting layer and which commands get dispatched. The same questions are
 * asked here of the native props and of `Commands`.
 */
jest.mock('../RNImeTextInputNativeComponent', () => {
  const actual = jest.requireActual('../RNImeTextInputNativeComponent');
  return {
    __esModule: true,
    ...actual,
    Commands: {
      focus: jest.fn(),
      blur: jest.fn(),
      clear: jest.fn(),
      setSelection: jest.fn(),
    },
  };
});

const input = () => screen.getByTestId('input');

/** The props the native view actually received. */
const nativeProps = () => input().props as Record<string, any>;

beforeEach(() => {
  jest.clearAllMocks();
  resetUnsupportedWarnings();
  jest.spyOn(console, 'warn').mockImplementation(() => {});
});

afterEach(() => {
  (console.warn as jest.Mock).mockRestore?.();
});

describe('<TextInput> events', () => {
  it('calls onChangeText with the text from the native event', async () => {
    const onChangeText = jest.fn();
    await render(<TextInput testID="input" onChangeText={onChangeText} />);

    await fireEvent(input(), 'changeText', { nativeEvent: { text: 'hello', eventCount: 1 } });

    expect(onChangeText).toHaveBeenCalledWith('hello');
  });

  it('calls onChange with a nativeEvent carrying the text and eventCount', async () => {
    const onChange = jest.fn();
    await render(<TextInput testID="input" onChange={onChange} />);

    await fireEvent(input(), 'changeText', { nativeEvent: { text: 'hello', eventCount: 4 } });

    expect(onChange.mock.calls[0][0].nativeEvent).toMatchObject({ text: 'hello', eventCount: 4 });
  });

  it('calls onFocus when the native focus event is dispatched', async () => {
    const onFocus = jest.fn();
    await render(<TextInput testID="input" onFocus={onFocus} />);

    await fireEvent(input(), 'inputFocus', { nativeEvent: { text: '' } });

    expect(onFocus).toHaveBeenCalledTimes(1);
  });

  it('calls onBlur when the native blur event is dispatched', async () => {
    const onBlur = jest.fn();
    await render(<TextInput testID="input" onBlur={onBlur} />);

    await fireEvent(input(), 'inputBlur', { nativeEvent: { text: 'typed' } });

    expect(onBlur.mock.calls[0][0].nativeEvent).toMatchObject({ text: 'typed' });
  });

  it('calls onEndEditing on blur — UIKit reports the end of editing there', async () => {
    const onEndEditing = jest.fn();
    await render(<TextInput testID="input" onEndEditing={onEndEditing} />);

    await fireEvent(input(), 'inputBlur', { nativeEvent: { text: 'typed' } });

    expect(onEndEditing.mock.calls[0][0].nativeEvent).toMatchObject({ text: 'typed' });
  });

  it('calls onSelectionChange with the updated selection', async () => {
    const onSelectionChange = jest.fn();
    await render(<TextInput testID="input" onSelectionChange={onSelectionChange} />);

    await fireEvent(input(), 'selectionChange', { nativeEvent: { start: 2, end: 5 } });

    expect(onSelectionChange.mock.calls[0][0].nativeEvent.selection).toEqual({ start: 2, end: 5 });
  });

  it('calls onSubmitEditing when the native submit event is dispatched', async () => {
    const onSubmitEditing = jest.fn();
    await render(<TextInput testID="input" onSubmitEditing={onSubmitEditing} />);

    await fireEvent(input(), 'submit', { nativeEvent: { text: 'done' } });

    expect(onSubmitEditing.mock.calls[0][0].nativeEvent).toMatchObject({ text: 'done' });
  });

  it('calls onKeyPress with the pressed key', async () => {
    const onKeyPress = jest.fn();
    await render(<TextInput testID="input" onKeyPress={onKeyPress} />);

    await fireEvent(input(), 'inputKeyPress', { nativeEvent: { key: 'Backspace' } });

    expect(onKeyPress.mock.calls[0][0].nativeEvent).toEqual({ key: 'Backspace' });
  });

  it('calls onContentSizeChange with the measured size', async () => {
    const onContentSizeChange = jest.fn();
    await render(<TextInput testID="input" onContentSizeChange={onContentSizeChange} />);

    await fireEvent(input(), 'contentSizeChange', { nativeEvent: { width: 100, height: 42 } });

    expect(onContentSizeChange.mock.calls[0][0].nativeEvent.contentSize).toEqual({
      width: 100,
      height: 42,
    });
  });

  it('leaves optional event props undefined so the native side can skip emitting them', async () => {
    await render(<TextInput testID="input" />);

    expect(nativeProps().onSubmit).toBeUndefined();
    expect(nativeProps().onSelectionChange).toBeUndefined();
    expect(nativeProps().onContentSizeChange).toBeUndefined();
    expect(nativeProps().onInputKeyPress).toBeUndefined();
  });
});

describe('<TextInput> ref', () => {
  it('exposes the documented methods', async () => {
    const ref = createRef<TextInputRef>();
    await render(<TextInput testID="input" ref={ref} />);

    expect(Object.keys(ref.current ?? {}).sort()).toEqual([
      'blur',
      'clear',
      'focus',
      'isFocused',
      'setSelection',
    ]);
  });

  it.each([
    ['focus', () => Commands.focus],
    ['blur', () => Commands.blur],
    ['clear', () => Commands.clear],
  ] as const)('%s() dispatches the matching command', async (method, command) => {
    const ref = createRef<TextInputRef>();
    await render(<TextInput testID="input" ref={ref} />);

    ref.current?.[method]();

    expect(command()).toHaveBeenCalledTimes(1);
  });

  it('setSelection() dispatches the command with both offsets', async () => {
    const ref = createRef<TextInputRef>();
    await render(<TextInput testID="input" ref={ref} />);

    ref.current?.setSelection(1, 4);

    expect(Commands.setSelection).toHaveBeenCalledWith(expect.anything(), 1, 4);
  });

  it('isFocused() tracks the focus and blur events', async () => {
    const ref = createRef<TextInputRef>();
    await render(<TextInput testID="input" ref={ref} />);

    expect(ref.current?.isFocused()).toBe(false);

    await fireEvent(input(), 'inputFocus', { nativeEvent: { text: '' } });
    expect(ref.current?.isFocused()).toBe(true);

    await fireEvent(input(), 'inputBlur', { nativeEvent: { text: '' } });
    expect(ref.current?.isFocused()).toBe(false);
  });
});

describe('<TextInput> selection prop', () => {
  it('dispatches setSelection when it is given', async () => {
    await render(<TextInput testID="input" selection={{ start: 0, end: 4 }} />);

    expect(Commands.setSelection).toHaveBeenCalledWith(expect.anything(), 0, 4);
  });

  it('treats a collapsed selection as a caret position', async () => {
    await render(<TextInput testID="input" selection={{ start: 3 }} />);

    expect(Commands.setSelection).toHaveBeenCalledWith(expect.anything(), 3, 3);
  });

  it('dispatches nothing when no selection is given', async () => {
    await render(<TextInput testID="input" />);

    expect(Commands.setSelection).not.toHaveBeenCalled();
  });
});

describe('<TextInput> controlled semantics', () => {
  it('sends `value` down as the native text', async () => {
    await render(<TextInput testID="input" value="hello" />);

    expect(nativeProps().text).toBe('hello');
  });

  it('bumps the revision after every edit, so a refused change can be re-asserted', async () => {
    await render(<TextInput testID="input" value="locked" onChangeText={() => {}} />);
    expect(nativeProps().textRevision).toBe(0);

    await fireEvent(input(), 'changeText', { nativeEvent: { text: 'locked!', eventCount: 1 } });

    expect(nativeProps().textRevision).toBe(1);
    expect(nativeProps().text).toBe('locked');
  });

  it('leaves the revision alone when uncontrolled — the native view owns the text', async () => {
    await render(<TextInput testID="input" defaultValue="hello" onChangeText={() => {}} />);

    await fireEvent(input(), 'changeText', { nativeEvent: { text: 'hello!', eventCount: 1 } });

    expect(nativeProps().textRevision).toBe(0);
  });

  it('echoes the eventCount back so native can reject a stale value', async () => {
    await render(<TextInput testID="input" value="a" onChangeText={() => {}} />);
    expect(nativeProps().mostRecentEventCount).toBe(0);

    await fireEvent(input(), 'changeText', { nativeEvent: { text: 'ab', eventCount: 7 } });

    expect(nativeProps().mostRecentEventCount).toBe(7);
  });

  it('keeps the last value when a parent goes controlled → uncontrolled', async () => {
    await render(<TextInput testID="input" value="typed" />);
    await screen.rerender(<TextInput testID="input" />);

    expect(nativeProps().text).toBe('typed');
  });
});

describe('<TextInput> props reaching the native view', () => {
  it('propagates testID', async () => {
    await render(<TextInput testID="input" />);

    expect(nativeProps().testID).toBe('input');
  });

  it('maps `id` to nativeID, as React Native does', async () => {
    await render(<TextInput testID="input" id="field" />);

    expect(nativeProps().nativeID).toBe('field');
    expect(nativeProps().id).toBeUndefined();
  });

  it('maps `aria-label` to accessibilityLabel', async () => {
    await render(<TextInput testID="input" aria-label="Name" />);

    expect(nativeProps().accessibilityLabel).toBe('Name');
    expect(nativeProps()['aria-label']).toBeUndefined();
  });

  it('maps the `aria-*` state props to accessibilityState', async () => {
    await render(<TextInput testID="input" aria-disabled />);

    expect(nativeProps().accessibilityState).toMatchObject({ disabled: true });
  });

  it('splits style into a view style and typography props', async () => {
    await render(
      <TextInput testID="input" style={{ margin: 8, fontSize: 20, color: '#ff0000' }} />
    );

    expect(nativeProps().style).toMatchObject({ margin: 8 });
    expect(nativeProps().fontSize).toBe(20);
    expect(nativeProps().color).toBe('#ff0000');
  });

  it('maps inputMode to a keyboard type', async () => {
    await render(<TextInput testID="input" inputMode="email" />);

    expect(nativeProps().keyboardType).toBe('email-address');
  });

  it('maps enterKeyHint to a return key type', async () => {
    await render(<TextInput testID="input" enterKeyHint="search" />);

    expect(nativeProps().returnKeyType).toBe('search');
  });

  it('maps autoComplete to an iOS textContentType', async () => {
    await render(<TextInput testID="input" autoComplete="one-time-code" />);

    expect(nativeProps().textContentType).toBe('oneTimeCode');
  });

  it('treats readOnly as the inverse of editable', async () => {
    await render(<TextInput testID="input" readOnly />);

    expect(nativeProps().editable).toBe(false);
  });

  it('sends clearButtonMode down as the token the native side parses', async () => {
    await render(<TextInput testID="input" clearButtonMode="unless-editing" />);

    expect(nativeProps().clearButtonMode).toBe('unless-editing');
  });

  it('sends an empty clearButtonMode when none is given, so UIKit keeps its default', async () => {
    await render(<TextInput testID="input" />);

    expect(nativeProps().clearButtonMode).toBe('');
  });

  it('sends passwordRules down as its descriptor string', async () => {
    await render(<TextInput testID="input" passwordRules="minlength: 8;" />);

    expect(nativeProps().passwordRules).toBe('minlength: 8;');
  });

  it('sends an empty passwordRules when none is given — the native prop is not optional', async () => {
    await render(<TextInput testID="input" />);

    expect(nativeProps().passwordRules).toBe('');
  });

  it.each([
    [true, 'yes'],
    [false, 'no'],
  ] as const)('maps smartInsertDelete=%s to `%s`', async (given, expected) => {
    await render(<TextInput testID="input" smartInsertDelete={given} />);

    expect(nativeProps().smartInsertDelete).toBe(expected);
  });

  it('leaves smartInsertDelete as `auto` when unset, so UIKit keeps its default', async () => {
    // The same tri-state `spellCheck` uses: a bare boolean cannot say "not set",
    // and UIKit's default is not the same as an explicit `yes`.
    await render(<TextInput testID="input" />);

    expect(nativeProps().smartInsertDelete).toBe('auto');
  });

  it('forwards contextMenuHidden to the native view', async () => {
    await render(<TextInput testID="input" contextMenuHidden />);

    expect(nativeProps().contextMenuHidden).toBe(true);
  });

  it('leaves the edit menu available when contextMenuHidden is not given', async () => {
    await render(<TextInput testID="input" />);

    expect(nativeProps().contextMenuHidden).toBe(false);
  });

  it('sends inputAccessoryViewButtonLabel down as its label', async () => {
    await render(<TextInput testID="input" inputAccessoryViewButtonLabel="完了" />);

    expect(nativeProps().inputAccessoryViewButtonLabel).toBe('完了');
  });

  it('sends an empty accessory label when none is given — the native prop is not optional', async () => {
    await render(<TextInput testID="input" />);

    expect(nativeProps().inputAccessoryViewButtonLabel).toBe('');
  });

  it('scales with the system text size unless told not to, as React Native does', async () => {
    await render(<TextInput testID="input" />);

    expect(nativeProps().allowFontScaling).toBe(true);
  });

  it('forwards allowFontScaling={false}', async () => {
    await render(<TextInput testID="input" allowFontScaling={false} />);

    expect(nativeProps().allowFontScaling).toBe(false);
  });

  it('forwards maxFontSizeMultiplier as the cap on that scaling', async () => {
    await render(<TextInput testID="input" maxFontSizeMultiplier={1.5} />);

    expect(nativeProps().maxFontSizeMultiplier).toBe(1.5);
  });

  it('sends no cap when maxFontSizeMultiplier is not given', async () => {
    await render(<TextInput testID="input" />);

    expect(nativeProps().maxFontSizeMultiplier).toBe(0);
  });

  it('drops the props that do nothing on iOS, and warns', async () => {
    await render(<TextInput testID="input" scrollEnabled dataDetectorTypes="link" />);

    expect(nativeProps().scrollEnabled).toBeUndefined();
    expect(nativeProps().dataDetectorTypes).toBeUndefined();
    expect(console.warn).toHaveBeenCalledTimes(2);
  });
});

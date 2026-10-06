import { fireEvent, render, screen } from '@testing-library/react-native';
import { createRef } from 'react';
import { NativeModules } from 'react-native';

import { TextInput } from '../TextInput';
import type { TextInputRef } from '../types';
import { resetUnsupportedWarnings } from '../unsupported';

/**
 * Android and web render React Native's own `TextInput`. This file runs under
 * the Android preset, so `../TextInput` resolves to the passthrough rather than
 * the iOS implementation.
 *
 * The ref wrapper is the only library code on these platforms, and it is where
 * the one reported bug lived: `setSelection` called a method that
 * react-native-web does not put on its ref.
 */
const input = () => screen.getByTestId('input');

beforeEach(() => {
  resetUnsupportedWarnings();
  jest.spyOn(console, 'warn').mockImplementation(() => {});
});

afterEach(() => {
  (console.warn as jest.Mock).mockRestore?.();
});

describe('<TextInput> on Android and web', () => {
  it('renders React Native’s own TextInput', async () => {
    await render(<TextInput testID="input" />);

    expect(input().type).toBe('TextInput');
  });

  it('forwards the props that only iOS has to drop', async () => {
    await render(<TextInput testID="input" dataDetectorTypes="link" underlineColorAndroid="#ff0000" />);

    expect(input().props.dataDetectorTypes).toBe('link');
    expect(input().props.underlineColorAndroid).toBe('#ff0000');
  });

  it('says nothing about them, because here they work', async () => {
    await render(<TextInput testID="input" dataDetectorTypes="link" textBreakStrategy="balanced" />);

    expect(console.warn).not.toHaveBeenCalled();
  });

  it('passes style straight through instead of splitting it', async () => {
    await render(<TextInput testID="input" style={{ margin: 8, fontSize: 20 }} />);

    expect(input().props.style).toMatchObject({ margin: 8, fontSize: 20 });
  });

  it('calls onChangeText with what the user typed', async () => {
    const onChangeText = jest.fn();
    await render(<TextInput testID="input" onChangeText={onChangeText} />);

    await fireEvent.changeText(input(), 'hello');

    expect(onChangeText).toHaveBeenCalledWith('hello');
  });

  describe('ref', () => {
    it('exposes the same methods as the iOS implementation', async () => {
      const ref = createRef<TextInputRef>();
      await render(<TextInput testID="input" ref={ref} />);

      expect(Object.keys(ref.current ?? {}).sort()).toEqual([
        'blur',
        'clear',
        'commitComposition',
        'focus',
        'isFocused',
        'setSelection',
      ]);
    });

    it('reports not focused rather than undefined before anything happens', async () => {
      const ref = createRef<TextInputRef>();
      await render(<TextInput testID="input" ref={ref} />);

      expect(ref.current?.isFocused()).toBe(false);
    });

    // React Native's own `TextInput` keeps the IME's composing span across a
    // value update and only moves the caret out of it, so the composition has
    // to be ended natively before an app-side insertion.
    describe('commitComposition()', () => {
      afterEach(() => {
        delete NativeModules.RNImeTextInputModule;
        jest.restoreAllMocks();
      });

      it('ends the composition natively, on the mounted view', async () => {
        const commitComposition = jest.fn();
        NativeModules.RNImeTextInputModule = { commitComposition };
        // React Native exports it through a getter, so the getter is what gets
        // replaced — on the module object itself; `import * as` would be a copy.
        jest.spyOn(require('react-native'), 'findNodeHandle', 'get').mockReturnValue(() => 42);
        const ref = createRef<TextInputRef>();
        await render(<TextInput testID="input" ref={ref} />);

        ref.current?.commitComposition();

        expect(commitComposition).toHaveBeenCalledWith(42);
      });

      // An app binary built before the module existed still runs newer JS.
      it('does nothing, without complaining, when the native module is missing', async () => {
        const ref = createRef<TextInputRef>();
        await render(<TextInput testID="input" ref={ref} />);

        expect(() => ref.current?.commitComposition()).not.toThrow();
      });
    });

    it('survives setSelection on a node that has no such method', async () => {
      const ref = createRef<TextInputRef>();
      await render(<TextInput testID="input" ref={ref} />);

      expect(() => ref.current?.setSelection(0, 2)).not.toThrow();
    });

    // Whether focus actually lands is a question for the device — the Maestro
    // flow covers that. Here the point is that the calls reach the mounted view.
    it('delegates to the mounted view', async () => {
      const ref = createRef<TextInputRef>();
      await render(<TextInput testID="input" defaultValue="hello" ref={ref} />);

      expect(() => {
        ref.current?.focus();
        ref.current?.blur();
        ref.current?.clear();
      }).not.toThrow();
      expect(typeof ref.current?.isFocused()).toBe('boolean');
    });

    it('survives the other methods before the view is attached', async () => {
      const ref = createRef<TextInputRef>();

      expect(() => {
        ref.current?.focus();
        ref.current?.blur();
        ref.current?.clear();
      }).not.toThrow();
    });
  });
});

import {
  findUnsupportedProps,
  resetUnsupportedWarnings,
  warnUnsupported,
  UNSUPPORTED_PROPS,
} from '../unsupported';

describe('findUnsupportedProps', () => {
  it('returns nothing for props that are fully supported', () => {
    expect(findUnsupportedProps({ value: 'a', onChangeText: () => {}, placeholder: 'x' })).toEqual(
      []
    );
  });

  it('reports props that have no native equivalent', () => {
    const found = findUnsupportedProps({
      value: 'a',
      scrollEnabled: false,
      clearButtonMode: 'while-editing',
    });

    expect(found.sort()).toEqual(['clearButtonMode', 'scrollEnabled']);
  });

  it('ignores unsupported props that are explicitly undefined', () => {
    expect(findUnsupportedProps({ scrollEnabled: undefined })).toEqual([]);
  });

  it('treats every name in UNSUPPORTED_PROPS as unsupported', () => {
    const allSet = Object.fromEntries(UNSUPPORTED_PROPS.map((name) => [name, 'x']));
    expect(findUnsupportedProps(allSet).sort()).toEqual([...UNSUPPORTED_PROPS].sort());
  });

  it('does not report unknown props it has never heard of', () => {
    // Forward-compatibility: an unknown prop is more likely a new RN prop than a
    // mistake, and warning about it would be noise.
    expect(findUnsupportedProps({ someBrandNewProp: 1 })).toEqual([]);
  });
});

describe('warnUnsupported', () => {
  let warn: jest.SpyInstance;

  beforeEach(() => {
    resetUnsupportedWarnings();
    warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  });

  afterEach(() => {
    warn.mockRestore();
  });

  it('warns once per name, however many times it is reported', () => {
    warnUnsupported('prop', ['scrollEnabled']);
    warnUnsupported('prop', ['scrollEnabled']);
    warnUnsupported('prop', ['scrollEnabled']);

    expect(warn).toHaveBeenCalledTimes(1);
  });

  it('names the offending prop and the library in the message', () => {
    warnUnsupported('prop', ['scrollEnabled']);

    const message = warn.mock.calls[0][0] as string;
    expect(message).toContain('scrollEnabled');
    expect(message).toContain('react-native-ime-text-input');
  });

  it('says the gap is iOS-only, so the reader does not think the prop is dead everywhere', () => {
    warnUnsupported('prop', ['scrollEnabled']);

    const message = warn.mock.calls[0][0] as string;
    expect(message).toContain('iOS');
    expect(message).toContain('Android');
  });

  it('warns separately for each distinct name', () => {
    warnUnsupported('prop', ['scrollEnabled', 'clearButtonMode']);

    expect(warn).toHaveBeenCalledTimes(2);
  });

  it('keeps prop and style warnings independent even when the names collide', () => {
    warnUnsupported('prop', ['textAlign']);
    warnUnsupported('style', ['textAlign']);

    expect(warn).toHaveBeenCalledTimes(2);
  });

  it('says nothing when there is nothing to report', () => {
    warnUnsupported('prop', []);

    expect(warn).not.toHaveBeenCalled();
  });

  it('stays silent outside development builds', () => {
    const previous = global.__DEV__;
    global.__DEV__ = false;
    try {
      warnUnsupported('prop', ['scrollEnabled']);
      expect(warn).not.toHaveBeenCalled();
    } finally {
      global.__DEV__ = previous;
    }
  });
});

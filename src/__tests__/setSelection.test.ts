import { setSelectionOn } from '../setSelection';

describe('setSelectionOn', () => {
  let warn: jest.SpyInstance;

  beforeEach(() => {
    warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  });

  afterEach(() => {
    warn.mockRestore();
  });

  it('calls setSelection when the node has it, as React Native does on Android', () => {
    const node = { setSelection: jest.fn() };

    setSelectionOn(node, 2, 5);

    expect(node.setSelection).toHaveBeenCalledWith(2, 5);
  });

  it('falls back to the DOM setSelectionRange, which is all react-native-web exposes', () => {
    const node = { setSelectionRange: jest.fn() };

    setSelectionOn(node, 2, 5);

    expect(node.setSelectionRange).toHaveBeenCalledWith(2, 5);
  });

  it('prefers setSelection when a node happens to have both', () => {
    const node = { setSelection: jest.fn(), setSelectionRange: jest.fn() };

    setSelectionOn(node, 0, 1);

    expect(node.setSelection).toHaveBeenCalled();
    expect(node.setSelectionRange).not.toHaveBeenCalled();
  });

  it('does nothing when there is no node — the ref may not be attached yet', () => {
    expect(() => setSelectionOn(null, 0, 1)).not.toThrow();
    expect(warn).not.toHaveBeenCalled();
  });

  it('warns rather than throwing when the node offers neither method', () => {
    expect(() => setSelectionOn({}, 0, 1)).not.toThrow();

    expect(warn).toHaveBeenCalledTimes(1);
    expect(warn.mock.calls[0][0]).toContain('setSelection');
  });
});

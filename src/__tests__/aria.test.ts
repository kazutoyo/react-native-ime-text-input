import { ARIA_PROPS, mapAriaProps } from '../aria';

describe('mapAriaProps', () => {
  it('returns nothing for props that use none of them', () => {
    expect(mapAriaProps({ placeholder: 'hi' })).toEqual({});
  });

  describe('nativeID', () => {
    it('maps `id`, the modern spelling', () => {
      expect(mapAriaProps({ id: 'field' })).toEqual({ nativeID: 'field' });
    });

    it('passes `nativeID` through', () => {
      expect(mapAriaProps({ nativeID: 'field' })).toEqual({ nativeID: 'field' });
    });

    it('gives `id` precedence, as React Native does', () => {
      expect(mapAriaProps({ id: 'new', nativeID: 'old' })).toEqual({ nativeID: 'new' });
    });
  });

  describe('accessibilityLabel', () => {
    it('maps `aria-label`', () => {
      expect(mapAriaProps({ 'aria-label': 'Name' })).toEqual({ accessibilityLabel: 'Name' });
    });

    it('gives `aria-label` precedence over `accessibilityLabel`', () => {
      expect(mapAriaProps({ 'aria-label': 'new', accessibilityLabel: 'old' })).toEqual({
        accessibilityLabel: 'new',
      });
    });
  });

  describe('accessibilityState', () => {
    it('collects the `aria-*` state props', () => {
      expect(mapAriaProps({ 'aria-busy': true, 'aria-disabled': false })).toEqual({
        accessibilityState: { busy: true, checked: undefined, disabled: false, expanded: undefined, selected: undefined },
      });
    });

    it('merges over an explicit accessibilityState, with `aria-*` winning', () => {
      expect(
        mapAriaProps({ 'aria-selected': true, accessibilityState: { selected: false, busy: true } })
      ).toEqual({
        accessibilityState: { busy: true, checked: undefined, disabled: undefined, expanded: undefined, selected: true },
      });
    });

    it('is left alone when neither is given, so the native default stands', () => {
      expect(mapAriaProps({ 'aria-label': 'Name' })).toEqual({ accessibilityLabel: 'Name' });
    });
  });

  describe('iOS-only mappings', () => {
    it('maps `aria-labelledby`', () => {
      expect(mapAriaProps({ 'aria-labelledby': 'label-1' })).toEqual({
        accessibilityLabelledBy: 'label-1',
      });
    });

    it('maps `aria-hidden` to accessibilityElementsHidden', () => {
      expect(mapAriaProps({ 'aria-hidden': true })).toEqual({
        accessibilityElementsHidden: true,
      });
    });
  });

  it('lists every prop it consumes, so the caller can drop them before they reach the view', () => {
    for (const name of ARIA_PROPS) {
      expect(mapAriaProps({ [name]: 'x' })).not.toEqual({});
    }
  });
});

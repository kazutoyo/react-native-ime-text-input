import type { TextStyle } from 'react-native';

import { splitStyle } from '../splitStyle';

describe('splitStyle', () => {
  it('returns empty buckets for an empty style', () => {
    expect(splitStyle({})).toEqual({ viewStyle: {}, text: {}, unsupported: [] });
  });

  describe('view style', () => {
    it('leaves box and layout properties on the native view', () => {
      const style: TextStyle = {
        margin: 8,
        flex: 1,
        paddingHorizontal: 12,
        backgroundColor: '#fff',
        borderRadius: 8,
        borderWidth: 1,
        borderColor: '#ccc',
        height: 40,
        maxHeight: 120,
        opacity: 0.9,
      };

      expect(splitStyle(style).viewStyle).toEqual(style);
    });

    it('keeps properties it has never heard of, so new React Native style props still reach the view', () => {
      expect(splitStyle({ transform: [{ scale: 2 }] } as TextStyle).viewStyle).toEqual({
        transform: [{ scale: 2 }],
      });
    });
  });

  describe('text style', () => {
    it('extracts the properties the native text view needs as props', () => {
      const result = splitStyle({
        fontSize: 17,
        fontFamily: 'Menlo',
        color: '#111',
        textAlign: 'center',
      });

      expect(result.text).toEqual({
        fontSize: 17,
        fontFamily: 'Menlo',
        color: '#111',
        textAlign: 'center',
      });
      expect(result.viewStyle).toEqual({});
    });

    it('normalizes a numeric fontWeight to the string form the native side expects', () => {
      expect(splitStyle({ fontWeight: 600 }).text).toEqual({ fontWeight: '600' });
    });

    it('passes through named fontWeight values unchanged', () => {
      expect(splitStyle({ fontWeight: 'bold' }).text).toEqual({ fontWeight: 'bold' });
    });

    it.each([
      ['ultralight', '100'],
      ['medium', '500'],
      ['semibold', '600'],
      ['heavy', '800'],
      ['black', '900'],
    ] as const)('maps the named weight %s to %s', (named, numeric) => {
      expect(splitStyle({ fontWeight: named as TextStyle['fontWeight'] }).text).toEqual({
        fontWeight: numeric,
      });
    });

    it('reports fontWeight values with no numeric equivalent', () => {
      const result = splitStyle({ fontWeight: 'chunky' as TextStyle['fontWeight'] });
      expect(result.text).toEqual({});
      expect(result.unsupported).toEqual(['fontWeight']);
    });

    it('drops textAlign `auto`, which is already the default', () => {
      expect(splitStyle({ textAlign: 'auto' })).toEqual({
        viewStyle: {},
        text: {},
        unsupported: [],
      });
    });
  });

  describe('attributed-text properties', () => {
    it('extracts line height and letter spacing', () => {
      const result = splitStyle({ lineHeight: 22, letterSpacing: 0.5 });

      expect(result.text).toEqual({ lineHeight: 22, letterSpacing: 0.5 });
      expect(result.unsupported).toEqual([]);
    });

    it('extracts italics', () => {
      expect(splitStyle({ fontStyle: 'italic' }).text).toEqual({ fontStyle: 'italic' });
    });

    it('extracts text decoration', () => {
      const result = splitStyle({
        textDecorationLine: 'underline',
        textDecorationColor: '#f00',
        textDecorationStyle: 'dotted',
      });

      expect(result.text).toEqual({
        textDecorationLine: 'underline',
        textDecorationColor: '#f00',
        textDecorationStyle: 'dotted',
      });
    });

    it('extracts a text shadow', () => {
      const result = splitStyle({
        textShadowColor: '#000',
        textShadowOffset: { width: 1, height: 2 },
        textShadowRadius: 3,
      });

      expect(result.text).toEqual({
        textShadowColor: '#000',
        textShadowOffset: { width: 1, height: 2 },
        textShadowRadius: 3,
      });
    });
  });

  describe('unsupported properties', () => {
    it('reports text properties with no UIKit equivalent', () => {
      const result = splitStyle({
        textTransform: 'uppercase',
        includeFontPadding: false,
        textAlignVertical: 'top',
      });

      expect(result.text).toEqual({});
      expect(result.unsupported.sort()).toEqual([
        'includeFontPadding',
        'textAlignVertical',
        'textTransform',
      ]);
    });
  });

  describe('undefined values', () => {
    it('ignores explicitly undefined properties', () => {
      expect(splitStyle({ color: undefined, margin: undefined, textTransform: undefined })).toEqual({
        viewStyle: {},
        text: {},
        unsupported: [],
      });
    });
  });

  it('splits a realistic input style', () => {
    const result = splitStyle({
      marginBottom: 12,
      paddingHorizontal: 12,
      borderWidth: 1,
      borderColor: '#c7c7cc',
      borderRadius: 8,
      fontSize: 17,
      color: '#000',
      lineHeight: 22,
      textTransform: 'uppercase',
    });

    expect(result.viewStyle).toEqual({
      marginBottom: 12,
      paddingHorizontal: 12,
      borderWidth: 1,
      borderColor: '#c7c7cc',
      borderRadius: 8,
    });
    expect(result.text).toEqual({ fontSize: 17, color: '#000', lineHeight: 22 });
    expect(result.unsupported).toEqual(['textTransform']);
  });
});

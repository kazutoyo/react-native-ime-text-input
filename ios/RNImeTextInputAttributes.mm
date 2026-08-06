#import "RNImeTextInputAttributes.h"

@implementation RNImeTextInputAttributes

- (instancetype)init
{
  if (self = [super init]) {
    _fontSize = 17;
    _fontSizeMultiplier = 1;
    _fontWeight = UIFontWeightRegular;
    _textAlign = NSTextAlignmentNatural;
    _decorationStyle = NSUnderlineStyleSingle;
    _shadowOffset = CGSizeZero;
    _writingDirection = NSWritingDirectionNatural;
  }
  return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  RNImeTextInputAttributes *copy = [[RNImeTextInputAttributes allocWithZone:zone] init];
  copy.fontSize = _fontSize;
  copy.fontSizeMultiplier = _fontSizeMultiplier;
  copy.fontWeight = _fontWeight;
  copy.fontFamily = _fontFamily;
  copy.italic = _italic;
  copy.color = _color;
  copy.textAlign = _textAlign;
  copy.lineHeight = _lineHeight;
  copy.letterSpacing = _letterSpacing;
  copy.underline = _underline;
  copy.strikethrough = _strikethrough;
  copy.decorationColor = _decorationColor;
  copy.decorationStyle = _decorationStyle;
  copy.shadowColor = _shadowColor;
  copy.shadowOffset = _shadowOffset;
  copy.shadowRadius = _shadowRadius;
  copy.writingDirection = _writingDirection;
  return copy;
}

/// The point size actually asked of UIKit: the style's size scaled by the
/// system text size setting. Every branch of `font` resolves against this, so
/// a named family scales the same way the system font does.
- (CGFloat)scaledFontSize
{
  return _fontSize * _fontSizeMultiplier;
}

- (UIFont *)font
{
  CGFloat size = [self scaledFontSize];
  UIFont *base = nil;
  if (_fontFamily.length > 0) {
    // A custom family has to be resolved together with the weight and italic
    // traits — `fontWithName:` alone always returns the regular face, so
    // {fontFamily: 'Avenir', fontWeight: '700'} would silently lose its bold.
    NSMutableDictionary *traits = [NSMutableDictionary new];
    traits[UIFontWeightTrait] = @(_fontWeight);
    if (_italic) {
      traits[UIFontSymbolicTrait] = @(UIFontDescriptorTraitItalic);
    }
    UIFontDescriptor *descriptor = [UIFontDescriptor fontDescriptorWithFontAttributes:@{
      UIFontDescriptorFamilyAttribute : _fontFamily,
      UIFontDescriptorTraitsAttribute : traits,
    }];
    base = [UIFont fontWithDescriptor:descriptor size:size];
    // `fontFamily` may also be a full face name ('Avenir-Heavy'), which the
    // family attribute cannot resolve.
    if (base == nil || ![base.familyName isEqualToString:_fontFamily]) {
      UIFont *byName = [UIFont fontWithName:_fontFamily size:size];
      if (byName != nil) {
        base = byName;
      }
    }
    if (base != nil) {
      if (!_italic || (base.fontDescriptor.symbolicTraits & UIFontDescriptorTraitItalic)) {
        return base;
      }
      UIFontDescriptor *italicised = [base.fontDescriptor
          fontDescriptorWithSymbolicTraits:(base.fontDescriptor.symbolicTraits |
                                            UIFontDescriptorTraitItalic)];
      return italicised ? [UIFont fontWithDescriptor:italicised size:size] : base;
    }
  }

  base = [UIFont systemFontOfSize:size weight:_fontWeight];
  if (!_italic) {
    return base;
  }
  UIFontDescriptor *descriptor =
      [base.fontDescriptor fontDescriptorWithSymbolicTraits:(base.fontDescriptor.symbolicTraits |
                                                             UIFontDescriptorTraitItalic)];
  return descriptor ? [UIFont fontWithDescriptor:descriptor size:size] : base;
}

- (NSDictionary<NSAttributedStringKey, id> *)attributes
{
  NSMutableDictionary<NSAttributedStringKey, id> *attributes = [NSMutableDictionary dictionary];
  attributes[NSFontAttributeName] = self.font;

  if (_color != nil) {
    attributes[NSForegroundColorAttributeName] = _color;
  }

  BOOL needsParagraphStyle =
      _lineHeight > 0 || _textAlign != NSTextAlignmentNatural || _writingDirection != NSWritingDirectionNatural;
  if (needsParagraphStyle) {
    NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
    paragraphStyle.alignment = _textAlign;
    if (_lineHeight > 0) {
      // Scaled alongside the font, as React Native does
      // (`RCTAttributedTextUtils.mm:229-232`). A fixed line height would crowd
      // the lines together exactly when the text got bigger. Letter spacing is
      // deliberately left alone — React Native does not scale kerning either.
      CGFloat lineHeight = _lineHeight * _fontSizeMultiplier;
      paragraphStyle.minimumLineHeight = lineHeight;
      paragraphStyle.maximumLineHeight = lineHeight;
    }
    if (_writingDirection != NSWritingDirectionNatural) {
      paragraphStyle.baseWritingDirection = _writingDirection;
    }
    attributes[NSParagraphStyleAttributeName] = paragraphStyle;
  }

  if (_letterSpacing != 0) {
    attributes[NSKernAttributeName] = @(_letterSpacing);
  }
  if (_underline) {
    attributes[NSUnderlineStyleAttributeName] = @(_decorationStyle);
    if (_decorationColor != nil) {
      attributes[NSUnderlineColorAttributeName] = _decorationColor;
    }
  }
  if (_strikethrough) {
    attributes[NSStrikethroughStyleAttributeName] = @(_decorationStyle);
    if (_decorationColor != nil) {
      attributes[NSStrikethroughColorAttributeName] = _decorationColor;
    }
  }
  // Only when a shadow was actually asked for. An empty `NSShadow` — and any
  // `NSBackgroundColor`, which is never emitted — stops UIKit rendering the IME
  // composition underline.
  if (_shadowColor != nil) {
    NSShadow *shadow = [NSShadow new];
    shadow.shadowColor = _shadowColor;
    shadow.shadowOffset = _shadowOffset;
    shadow.shadowBlurRadius = _shadowRadius;
    attributes[NSShadowAttributeName] = shadow;
  }

  return attributes;
}

- (BOOL)isEqualToAttributes:(RNImeTextInputAttributes *)other
{
  if (other == nil) {
    return NO;
  }
  return _fontSize == other.fontSize && _fontSizeMultiplier == other.fontSizeMultiplier &&
      _fontWeight == other.fontWeight &&
      (_fontFamily == other.fontFamily || [_fontFamily isEqualToString:other.fontFamily]) &&
      _italic == other.italic && (_color == other.color || [_color isEqual:other.color]) &&
      _textAlign == other.textAlign && _lineHeight == other.lineHeight &&
      _letterSpacing == other.letterSpacing && _underline == other.underline &&
      _strikethrough == other.strikethrough &&
      (_decorationColor == other.decorationColor || [_decorationColor isEqual:other.decorationColor]) &&
      _decorationStyle == other.decorationStyle &&
      (_shadowColor == other.shadowColor || [_shadowColor isEqual:other.shadowColor]) &&
      CGSizeEqualToSize(_shadowOffset, other.shadowOffset) && _shadowRadius == other.shadowRadius &&
      _writingDirection == other.writingDirection;
}

@end

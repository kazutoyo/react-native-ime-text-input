#pragma once

#import <UIKit/UIKit.h>

/**
 The typography that becomes `NSAttributedString` attributes.

 Text attributes are what break IME composition in React Native, but not because
 attributes are inherently unsafe. The causes documented in
 facebook/react-native#56082 are that React Native reapplies them while a
 conversion is open, and that no-op `NSShadow` / transparent
 `NSBackgroundColor` entries reach UIKit and stop it drawing the composition
 underline.

 Both are avoided here: `attributes` is always built from scratch (so UIKit's
 own defaults are never read back and propagated), a shadow is emitted only when
 one was actually asked for, and `NSBackgroundColor` is never emitted at all.
 Applying the result is deferred until the conversion commits — see
 `-[RNImeTextInput applyTextAttributes]`.
 */
@interface RNImeTextInputAttributes : NSObject <NSCopying>

@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, assign) UIFontWeight fontWeight;
@property (nonatomic, copy, nullable) NSString *fontFamily;
@property (nonatomic, assign) BOOL italic;
@property (nonatomic, strong, nullable) UIColor *color;
@property (nonatomic, assign) NSTextAlignment textAlign;
/** 0 means unset: the font's natural line height is used. */
@property (nonatomic, assign) CGFloat lineHeight;
/** 0 means no extra tracking. */
@property (nonatomic, assign) CGFloat letterSpacing;
@property (nonatomic, assign) BOOL underline;
@property (nonatomic, assign) BOOL strikethrough;
@property (nonatomic, strong, nullable) UIColor *decorationColor;
@property (nonatomic, assign) NSUnderlineStyle decorationStyle;
@property (nonatomic, strong, nullable) UIColor *shadowColor;
@property (nonatomic, assign) CGSize shadowOffset;
@property (nonatomic, assign) CGFloat shadowRadius;
/** `NSWritingDirectionNatural` means unset. */
@property (nonatomic, assign) NSWritingDirection writingDirection;

/** The resolved font, including the italic trait. */
@property (nonatomic, readonly, nonnull) UIFont *font;

/** The attribute dictionary. Never contains a no-op shadow or a background colour. */
- (nonnull NSDictionary<NSAttributedStringKey, id> *)attributes;

- (BOOL)isEqualToAttributes:(nullable RNImeTextInputAttributes *)other;

@end

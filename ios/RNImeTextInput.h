#pragma once

#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 A text input backed directly by UIKit.

 React Native's Fabric text input rewrites `attributedText` and reapplies text
 attributes while the user is composing, which destroys UIKit's marked-text
 state — that is why the underline under unconfirmed Japanese, Chinese, and
 Korean input never renders there. Owning the UIKit views avoids that path.

 Like React Native, a single-line field is a `UITextField` and a multiline field
 is a `UITextView`: the two differ in vertical centring, horizontal scrolling
 and secure-entry rendering, and emulating one with the other shows.
 */
@interface RNImeTextInput : RCTViewComponentView
@end

NS_ASSUME_NONNULL_END

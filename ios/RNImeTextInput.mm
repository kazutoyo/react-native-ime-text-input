#import "RNImeTextInput.h"

#import <React/RCTConversions.h>
#import <React/RCTTextInputUtils.h>
#import <react/renderer/components/RNImeTextInputSpec/EventEmitters.h>
#import <react/renderer/components/RNImeTextInputSpec/Props.h>
#import <react/renderer/components/RNImeTextInputSpec/RCTComponentViewHelpers.h>

#import "RNImeTextInputAttributes.h"
#import "RNImeTextInputComponentDescriptor.h"

using namespace facebook::react;

#pragma mark - Conversions

// SYNC: every value parsed here must match what `src/TextInput.ios.tsx` sends.
// The props arrive as plain strings on purpose — see the comment in
// `src/RNImeTextInputNativeComponent.ts`.

static UIFontWeight RNImeTextInputFontWeight(const std::string &value)
{
  if (value == "100") return UIFontWeightUltraLight;
  if (value == "200") return UIFontWeightThin;
  if (value == "300") return UIFontWeightLight;
  if (value == "500") return UIFontWeightMedium;
  if (value == "600") return UIFontWeightSemibold;
  if (value == "700" || value == "bold") return UIFontWeightBold;
  if (value == "800") return UIFontWeightHeavy;
  if (value == "900") return UIFontWeightBlack;
  return UIFontWeightRegular;
}

static NSTextAlignment RNImeTextInputAlignment(const std::string &value)
{
  if (value == "left") return NSTextAlignmentLeft;
  if (value == "right") return NSTextAlignmentRight;
  if (value == "center") return NSTextAlignmentCenter;
  if (value == "justify") return NSTextAlignmentJustified;
  return NSTextAlignmentNatural;
}

static NSUnderlineStyle RNImeTextInputUnderlineStyle(const std::string &value)
{
  if (value == "double") return NSUnderlineStyleSingle | NSUnderlineStyleDouble;
  if (value == "dotted") return NSUnderlineStyleSingle | NSUnderlinePatternDot;
  if (value == "dashed") return NSUnderlineStyleSingle | NSUnderlinePatternDash;
  return NSUnderlineStyleSingle;
}

static NSWritingDirection RNImeTextInputWritingDirection(const std::string &value)
{
  if (value == "ltr") return NSWritingDirectionLeftToRight;
  if (value == "rtl") return NSWritingDirectionRightToLeft;
  return NSWritingDirectionNatural;
}

static UIKeyboardType RNImeTextInputKeyboardType(const std::string &value)
{
  if (value == "number-pad") return UIKeyboardTypeNumberPad;
  if (value == "decimal-pad") return UIKeyboardTypeDecimalPad;
  if (value == "numeric") return UIKeyboardTypeNumbersAndPunctuation;
  if (value == "email-address") return UIKeyboardTypeEmailAddress;
  if (value == "phone-pad") return UIKeyboardTypePhonePad;
  if (value == "url") return UIKeyboardTypeURL;
  if (value == "ascii-capable") return UIKeyboardTypeASCIICapable;
  if (value == "numbers-and-punctuation") return UIKeyboardTypeNumbersAndPunctuation;
  if (value == "name-phone-pad") return UIKeyboardTypeNamePhonePad;
  if (value == "twitter") return UIKeyboardTypeTwitter;
  if (value == "web-search") return UIKeyboardTypeWebSearch;
  return UIKeyboardTypeDefault;
}

static UIReturnKeyType RNImeTextInputReturnKeyType(const std::string &value)
{
  if (value == "go") return UIReturnKeyGo;
  if (value == "google") return UIReturnKeyGoogle;
  if (value == "join") return UIReturnKeyJoin;
  if (value == "next") return UIReturnKeyNext;
  if (value == "route") return UIReturnKeyRoute;
  if (value == "search") return UIReturnKeySearch;
  if (value == "send") return UIReturnKeySend;
  if (value == "yahoo") return UIReturnKeyYahoo;
  if (value == "done") return UIReturnKeyDone;
  if (value == "emergency-call") return UIReturnKeyEmergencyCall;
  if (value == "continue") return UIReturnKeyContinue;
  return UIReturnKeyDefault;
}

static UITextAutocapitalizationType RNImeTextInputAutocapitalization(const std::string &value)
{
  if (value == "none") return UITextAutocapitalizationTypeNone;
  if (value == "words") return UITextAutocapitalizationTypeWords;
  if (value == "characters") return UITextAutocapitalizationTypeAllCharacters;
  return UITextAutocapitalizationTypeSentences;
}

/*
 * The return keys React Native is willing to draw a button for, and the titles
 * it draws — `RCTTextInputComponentView`'s `returnKeyTypesSet` and
 * `returnKeyTypeToString:`. `UIReturnKeyDefault` is deliberately absent: a
 * number pad with no chosen return key gets no button, because there would be
 * nothing meaningful to write on it.
 */
static BOOL RNImeTextInputReturnKeyIsLabelled(UIReturnKeyType returnKeyType)
{
  switch (returnKeyType) {
    case UIReturnKeyDone:
    case UIReturnKeyGo:
    case UIReturnKeyNext:
    case UIReturnKeySearch:
    case UIReturnKeySend:
    case UIReturnKeyYahoo:
    case UIReturnKeyGoogle:
    case UIReturnKeyRoute:
    case UIReturnKeyJoin:
    case UIReturnKeyEmergencyCall:
      return YES;
    default:
      return NO;
  }
}

static NSString *RNImeTextInputReturnKeyTitle(UIReturnKeyType returnKeyType)
{
  switch (returnKeyType) {
    case UIReturnKeyGo: return @"Go";
    case UIReturnKeyNext: return @"Next";
    case UIReturnKeySearch: return @"Search";
    case UIReturnKeySend: return @"Send";
    case UIReturnKeyYahoo: return @"Yahoo";
    case UIReturnKeyGoogle: return @"Google";
    case UIReturnKeyRoute: return @"Route";
    case UIReturnKeyJoin: return @"Join";
    case UIReturnKeyEmergencyCall: return @"Emergency Call";
    default: return @"Done";
  }
}

static BOOL RNImeTextInputIsNumberPad(UIKeyboardType keyboardType)
{
  return keyboardType == UIKeyboardTypeNumberPad || keyboardType == UIKeyboardTypePhonePad ||
      keyboardType == UIKeyboardTypeDecimalPad || keyboardType == UIKeyboardTypeASCIICapableNumberPad;
}

static UITextSmartInsertDeleteType RNImeTextInputSmartInsertDelete(const std::string &value)
{
  if (value == "yes") return UITextSmartInsertDeleteTypeYes;
  if (value == "no") return UITextSmartInsertDeleteTypeNo;
  // "auto" and the empty default both mean "leave UIKit alone", which is not
  // the same as an explicit yes — the default also covers paste heuristics.
  return UITextSmartInsertDeleteTypeDefault;
}

static UITextFieldViewMode RNImeTextInputViewMode(const std::string &value)
{
  if (value == "while-editing") return UITextFieldViewModeWhileEditing;
  if (value == "unless-editing") return UITextFieldViewModeUnlessEditing;
  if (value == "always") return UITextFieldViewModeAlways;
  return UITextFieldViewModeNever;
}

static UIKeyboardAppearance RNImeTextInputKeyboardAppearance(const std::string &value)
{
  if (value == "light") return UIKeyboardAppearanceLight;
  if (value == "dark") return UIKeyboardAppearanceDark;
  return UIKeyboardAppearanceDefault;
}

#pragma mark - Backing views

/*
 * `contextMenuHidden` has no UIKit property behind it — refusing the edit menu
 * means overriding `canPerformAction:`, which is the only reason the backing
 * views are subclassed at all. React Native core subclasses for the same
 * reason (`RCTUITextField` / `RCTUITextView`).
 *
 * Everything else stays stock: the composition rules live in the component
 * view, not here, so these two add no behaviour that could interfere with them.
 */

/*
 * `inputAccessoryViewID` is never read back here. React Native's
 * `InputAccessoryView` walks the window looking for a view that answers to this
 * property and to `setInputAccessoryView:`, and assigns itself
 * (`RCTInputAccessoryComponentView`'s `RCTFindTextInputWithNativeId`). Carrying
 * the id is the entire contract; UIKit gives `setInputAccessoryView:` for free.
 */

@interface RNImeTextField : UITextField
@property (nonatomic, assign) BOOL contextMenuHidden;
@property (nonatomic, copy, nullable) NSString *inputAccessoryViewID;
@end

@interface RNImeTextView : UITextView
@property (nonatomic, assign) BOOL contextMenuHidden;
@property (nonatomic, copy, nullable) NSString *inputAccessoryViewID;
@end

/*
 * The two implementations below are deliberately identical. iOS 17 moved
 * autofill out of `canPerformAction:` and into the menu builder, so hiding the
 * menu takes both halves. The builder half is not unit-tested — a
 * `UIMenuBuilder` cannot be constructed outside a live menu presentation.
 */

@implementation RNImeTextField

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
  if (_contextMenuHidden) {
    return NO;
  }
  return [super canPerformAction:action withSender:sender];
}

- (void)buildMenuWithBuilder:(id<UIMenuBuilder>)builder
{
  if (@available(iOS 17.0, *)) {
    if (_contextMenuHidden) {
      [builder removeMenuForIdentifier:UIMenuAutoFill];
    }
  }
  [super buildMenuWithBuilder:builder];
}

@end

@implementation RNImeTextView

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
  if (_contextMenuHidden) {
    return NO;
  }
  return [super canPerformAction:action withSender:sender];
}

- (void)buildMenuWithBuilder:(id<UIMenuBuilder>)builder
{
  if (@available(iOS 17.0, *)) {
    if (_contextMenuHidden) {
      [builder removeMenuForIdentifier:UIMenuAutoFill];
    }
  }
  [super buildMenuWithBuilder:builder];
}

@end

#pragma mark - View

@interface RNImeTextInput () <RCTRNImeTextInputViewProtocol, UITextViewDelegate, UITextFieldDelegate>
@end

@implementation RNImeTextInput {
  RNImeTextField *_textField;
  RNImeTextView *_textView;
  UILabel *_placeholderLabel;

  RNImeTextInputAttributes *_attributes;

  /// The text JavaScript last asked for, so it can be re-asserted after an edit
  /// the parent chose not to accept.
  NSString *_jsText;
  /// Set while applying text that came from JavaScript, so the resulting
  /// delegate callback is not echoed back as a user edit.
  BOOL _applyingFromJS;
  /// Set when an attribute update arrived mid-conversion and still has to land.
  BOOL _pendingAttributeApply;
  BOOL _didAutoFocus;

  BOOL _multiline;
  BOOL _editable;
  BOOL _secureTextEntry;
  BOOL _autoFocus;
  BOOL _selectTextOnFocus;
  BOOL _clearTextOnFocus;
  BOOL _caretHidden;
  BOOL _contextMenuHidden;
  BOOL _allowFontScaling;
  CGFloat _maxFontSizeMultiplier;
  BOOL _autoCorrect;
  BOOL _enablesReturnKeyAutomatically;
  NSInteger _maxLength;
  std::string _submitBehavior;
  std::string _spellCheck;
  UIColor *_selectionColor;
  UIColor *_placeholderColor;
  NSString *_placeholder;
  UIKeyboardType _keyboardType;
  UIReturnKeyType _returnKeyType;
  UITextAutocapitalizationType _autocapitalizationType;
  UIKeyboardAppearance _keyboardAppearance;
  UITextContentType _textContentType;
  UITextSmartInsertDeleteType _smartInsertDelete;
  /// nil when no descriptor was given — an empty one is not the same as none.
  UITextInputPasswordRules *_passwordRules;
  /// `UITextView` has no clear button, so this only reaches the text field.
  UITextFieldViewMode _clearButtonMode;
  NSString *_accessoryButtonLabel;
  NSString *_accessoryViewID;
  /// The title currently drawn on the default accessory button, nil when there
  /// is none. Kept so the keyboard is only reloaded when it actually changes.
  NSString *_accessoryButtonTitle;

  CGSize _lastReportedContentSize;
  /// The Fabric state this view publishes its content size into. Retained as a
  /// shared_ptr (as RN core does, RCTTextInputComponentView.mm:46): the shadow
  /// thread releases old revisions concurrently with main-thread use, so a raw
  /// pointer here would dangle between commit and mount.
  RNImeTextInputShadowNodeImpl::ConcreteState::Shared _state;
  /// Insets from Yoga (border + padding). The text is framed inside them.
  UIEdgeInsets _contentInsets;
  UIEdgeInsets _borderInsets;
  /// Counts user edits, echoed back by JS as `mostRecentEventCount`, so a stale
  /// controlled value from before the latest keystroke is never applied.
  NSInteger _nativeEventCount;
  NSInteger _mostRecentEventCount;
  /// A JS-driven text value that arrived mid-composition, held until commit.
  NSString *_pendingJSText;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNImeTextInputComponentDescriptorImpl>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNImeTextInputProps>();
    _props = defaultProps;

    _attributes = [RNImeTextInputAttributes new];
    _jsText = nil;
    _editable = YES;
    _autoCorrect = YES;
    // React Native's default: text follows the system text size setting.
    _allowFontScaling = YES;
    _maxFontSizeMultiplier = 0;
    _maxLength = 0;
    _submitBehavior = "default";
    _spellCheck = "auto";
    _placeholder = @"";
    _keyboardType = UIKeyboardTypeDefault;
    _returnKeyType = UIReturnKeyDefault;
    _autocapitalizationType = UITextAutocapitalizationTypeSentences;
    _keyboardAppearance = UIKeyboardAppearanceDefault;
    _smartInsertDelete = UITextSmartInsertDeleteTypeDefault;
    _clearButtonMode = UITextFieldViewModeNever;
    _lastReportedContentSize = CGSizeZero;

    self.clipsToBounds = YES;

    _placeholderLabel = [UILabel new];
    _placeholderLabel.userInteractionEnabled = NO;
    _placeholderLabel.textColor = UIColor.placeholderTextColor;
    [self addSubview:_placeholderLabel];

    [self rebuildInput];
  }
  return self;
}

#pragma mark - Backing views

/// The active input, whichever kind it is.
- (UIView<UITextInput> *)input
{
  return _textView != nil ? (UIView<UITextInput> *)_textView : (UIView<UITextInput> *)_textField;
}

- (NSString *)currentText
{
  if (_textView != nil) {
    return _textView.text ?: @"";
  }
  return _textField.text ?: @"";
}

/**
 The view every accessibility prop is applied to.

 `RCTViewComponentView` writes `testID`, `accessibilityLabel`, traits and the
 rest onto `self.accessibilityElement`, which defaults to `self`. That host view
 is not what VoiceOver or an automation driver sees — the text view inside it is
 — so without this override `testID` never becomes an
 `accessibilityIdentifier` anything can find, and Maestro, Detox and XCUITest
 cannot target the field at all.

 SYNC: React Native's own `RCTTextInputComponentView` overrides this the same
 way, returning its `_backedTextInputView`.
 */
- (NSObject *)accessibilityElement
{
  return self.input ?: self;
}

/**
 Swaps the backing view when `multiline` changes, carrying the text and every
 applied prop across so the switch is invisible from JavaScript.
 */
- (void)rebuildInput
{
  NSString *previousText = [self currentText];
  BOOL wasFirstResponder = [self input].isFirstResponder;
  // An `InputAccessoryView` assigns itself to the backing view directly and
  // resolves its field only once, in `didMoveToWindow`, so an accessory dropped
  // here is gone for good. Core carries it across the same switch
  // (`RCTTextInputUtils.mm`'s `RCTCopyBackedTextInput`).
  UIView *previousAccessory = [self input].inputAccessoryView;

  [_textView removeFromSuperview];
  [_textField removeFromSuperview];
  _textView = nil;
  _textField = nil;

  if (_multiline) {
    RNImeTextView *view = [RNImeTextView new];
    view.delegate = self;
    view.backgroundColor = UIColor.clearColor;
    // `UITextView` insets its text by default; React Native's TextInput does
    // not, so padding is left entirely to the JavaScript style.
    view.textContainerInset = UIEdgeInsetsZero;
    view.textContainer.lineFragmentPadding = 0;
    view.adjustsFontForContentSizeCategory = NO;
    view.scrollEnabled = YES;
    _textView = view;
    [self insertSubview:view atIndex:0];
  } else {
    RNImeTextField *field = [RNImeTextField new];
    field.delegate = self;
    field.backgroundColor = UIColor.clearColor;
    [field addTarget:self action:@selector(textFieldDidChange) forControlEvents:UIControlEventEditingChanged];
    _textField = field;
    [self insertSubview:field atIndex:0];
  }

  [self applyTextAttributes];
  [self applyPlaceholder];
  [self applyEditable];
  [self applySecureTextEntry];
  [self applyKeyboardTraits];
  [self applyTint];
  [self applyContextMenuHidden];
  // Before the default toolbar: it steps aside when an id is present.
  [self applyAccessoryViewID];
  _textView.inputAccessoryView = previousAccessory;
  _textField.inputAccessoryView = previousAccessory;
  // Overwrites the carried value when the toolbar is ours to draw, and leaves
  // it alone when an `inputAccessoryViewID` says it is not.
  [self applyDefaultInputAccessoryView];
  [self setTextValue:previousText fromJS:YES];

  if (wasFirstResponder) {
    [[self input] becomeFirstResponder];
  }
  [self setNeedsLayout];
}

- (void)updateLayoutMetrics:(const LayoutMetrics &)layoutMetrics
           oldLayoutMetrics:(const LayoutMetrics &)oldLayoutMetrics
{
  [super updateLayoutMetrics:layoutMetrics oldLayoutMetrics:oldLayoutMetrics];
  // Mirrors RN core (RCTTextInputComponentView.mm:361-369): the text view sits
  // inside the border, and the padding becomes a text inset. Style padding is
  // otherwise reserved by Yoga but never visually applied.
  _borderInsets = RCTUIEdgeInsetsFromEdgeInsets(layoutMetrics.borderWidth);
  _contentInsets = RCTUIEdgeInsetsFromEdgeInsets(layoutMetrics.contentInsets);
  [self setNeedsLayout];
}

/// Padding only — the part of the content insets inside the border.
- (UIEdgeInsets)paddingInsets
{
  return UIEdgeInsetsMake(
      _contentInsets.top - _borderInsets.top,
      _contentInsets.left - _borderInsets.left,
      _contentInsets.bottom - _borderInsets.bottom,
      _contentInsets.right - _borderInsets.right);
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  UIEdgeInsets padding = [self paddingInsets];
  if (_textView != nil) {
    // UITextView scrolls, so it fills the area inside the border and carries
    // the padding as a text-container inset — exactly as RN core does.
    _textView.frame = UIEdgeInsetsInsetRect(self.bounds, _borderInsets);
    _textView.textContainerInset = padding;
  } else {
    // UITextField has no text-container inset; framing it inside the full
    // content insets renders the same box.
    _textField.frame = UIEdgeInsetsInsetRect(self.bounds, _contentInsets);
  }
  [self layoutPlaceholder];
  [self notifyContentSizeChange];

  if (_autoFocus && !_didAutoFocus && self.window != nil) {
    _didAutoFocus = YES;
    [[self input] becomeFirstResponder];
  }
}

- (void)layoutPlaceholder
{
  if (!_multiline) {
    // `UITextField` draws its own placeholder, vertically centred.
    _placeholderLabel.hidden = YES;
    return;
  }
  CGRect area = UIEdgeInsetsInsetRect(self.bounds, _contentInsets);
  CGSize fitting = [_placeholderLabel sizeThatFits:CGSizeMake(area.size.width, CGFLOAT_MAX)];
  _placeholderLabel.frame = CGRectMake(area.origin.x, area.origin.y, area.size.width, fitting.height);
  [self updatePlaceholderVisibility];
}

#pragma mark - Text

- (void)setTextValue:(NSString *)newValue fromJS:(BOOL)fromJS
{
  if ([[self currentText] isEqualToString:newValue]) {
    return;
  }
  // Never rewrite the buffer mid-composition: doing so is exactly what clears
  // `markedTextRange` and drops the conversion underline. A JS-driven value is
  // recorded and applied by `handleTextChanged` when the conversion commits —
  // dropping it would leave the field permanently out of sync with the parent.
  if ([self input].markedTextRange != nil) {
    if (fromJS) {
      _pendingJSText = [newValue copy];
    }
    return;
  }
  _pendingJSText = nil;

  _applyingFromJS = fromJS;
  NSRange previousSelection = [self selectionRange];
  if (_textView != nil) {
    _textView.text = newValue;
  } else {
    _textField.text = newValue;
  }
  // Keep the caret where it was rather than letting it jump to the start.
  NSUInteger clamped = MIN(previousSelection.location, newValue.length);
  [self setSelectionStart:(NSInteger)clamped end:(NSInteger)clamped];
  _applyingFromJS = NO;

  [self updatePlaceholderVisibility];
  [self notifyContentSizeChange];
}

- (void)applyJSText
{
  if (_jsText == nil) {
    return;
  }
  // Stale guard, as RN's mostRecentEventCount: if the user has typed since the
  // event this value responds to, applying it would rewind the field only for
  // the newer change event to bounce it back — flicker and caret jumps. The
  // newer edit bumped the revision, so a fresh value is already on its way.
  if (_mostRecentEventCount < _nativeEventCount) {
    return;
  }
  [self setTextValue:_jsText fromJS:YES];
}

#pragma mark - Attributes

/**
 Applies the text attributes, or defers them if a conversion is open.

 Writing attributes while `markedTextRange` is set clears UIKit's marked-text
 state — cause 1 of react-native#56082, and the reason its composition underline
 disappears. Deferring costs nothing: the attributes land the moment the
 conversion commits, and `handleTextChanged` calls back in.
 */
/**
 The system text size setting as a scale factor.

 The table is React Native's (`RCTUtils.mm`'s `RCTFontSizeMultiplier`), so a
 field renders at the same size as the `Text` next to it. React Native reads it
 with the *application's* category; this reads the view's own, which is the same
 value in an ordinary app and does not need `RCTSharedApplication()` — that is
 nil in a unit test bundle, where the lookup below would throw.

 An unknown category means no scaling. React Native's dictionary lookup yields 0
 for one instead, which would resolve to a zero-point font; `unspecified` is
 exactly what a view reports before it joins a hierarchy.
 */
- (CGFloat)fontSizeMultiplierForContentSizeCategory:(UIContentSizeCategory)category
{
  static NSDictionary<UIContentSizeCategory, NSNumber *> *mapping;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    mapping = @{
      UIContentSizeCategoryExtraSmall : @0.823,
      UIContentSizeCategorySmall : @0.882,
      UIContentSizeCategoryMedium : @0.941,
      UIContentSizeCategoryLarge : @1.0,
      UIContentSizeCategoryExtraLarge : @1.118,
      UIContentSizeCategoryExtraExtraLarge : @1.235,
      UIContentSizeCategoryExtraExtraExtraLarge : @1.353,
      UIContentSizeCategoryAccessibilityMedium : @1.786,
      UIContentSizeCategoryAccessibilityLarge : @2.143,
      UIContentSizeCategoryAccessibilityExtraLarge : @2.643,
      UIContentSizeCategoryAccessibilityExtraExtraLarge : @3.143,
      UIContentSizeCategoryAccessibilityExtraExtraExtraLarge : @3.571,
    };
  });

  NSNumber *multiplier = category != nil ? mapping[category] : nil;
  return multiplier != nil ? multiplier.doubleValue : 1.0;
}

/**
 Applies `allowFontScaling` and `maxFontSizeMultiplier` to that scale.

 A cap below 1 is ignored rather than shrinking the text, matching
 `RCTAttributedTextUtils.mm`'s `RCTEffectiveFontSizeMultiplierFromTextAttributes`.
 */
- (CGFloat)effectiveFontSizeMultiplierForBase:(CGFloat)base
{
  if (!_allowFontScaling) {
    return 1.0;
  }
  if (_maxFontSizeMultiplier >= 1.0) {
    return MIN(_maxFontSizeMultiplier, base);
  }
  return base;
}

- (CGFloat)currentFontSizeMultiplier
{
  return [self effectiveFontSizeMultiplierForBase:
                   [self fontSizeMultiplierForContentSizeCategory:
                             self.traitCollection.preferredContentSizeCategory]];
}

/**
 Re-resolves the font after the system text size changed.

 Nothing in the props changes when the setting does, so this has to write the
 attributes itself — and it goes through `applyTextAttributes`, which holds them
 back while a conversion is open. A text size change is exactly the kind of
 update that arrives unannounced mid-input.
 */
- (void)contentSizeCategoryDidChange
{
  _attributes.fontSizeMultiplier = [self currentFontSizeMultiplier];
  [self applyTextAttributes];
  [self applyPlaceholder];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  [super traitCollectionDidChange:previousTraitCollection];

  if (![self.traitCollection.preferredContentSizeCategory
          isEqualToString:previousTraitCollection.preferredContentSizeCategory]) {
    [self contentSizeCategoryDidChange];
  }
}

- (void)applyTextAttributes
{
  if ([self input].markedTextRange != nil) {
    _pendingAttributeApply = YES;
    return;
  }
  _pendingAttributeApply = NO;

  NSDictionary<NSAttributedStringKey, id> *attributes = [_attributes attributes];

  if (_textField != nil) {
    _textField.defaultTextAttributes = attributes;
    // `defaultTextAttributes` carries its own paragraph style, so alignment has
    // to be restated afterwards.
    _textField.textAlignment = _attributes.textAlign;
  }
  if (_textView != nil) {
    _textView.typingAttributes = attributes;
    NSRange full = NSMakeRange(0, _textView.textStorage.length);
    if (full.length > 0) {
      // `setAttributes` restyles in place; it never replaces the string, so the
      // buffer — and any composition — is left alone.
      [_textView.textStorage setAttributes:attributes range:full];
    }
    _textView.textAlignment = _attributes.textAlign;
  }

  // The placeholder is drawn with the same attributes, so it moves with them.
  [self applyPlaceholder];
  [self setNeedsLayout];
  [self notifyContentSizeChange];
}

/**
 The attributes the placeholder is drawn with: the field's own, with the
 placeholder colour swapped in.

 SYNC: React Native builds its placeholder the same way — `RCTUITextView`'s
 `_placeholderTextAttributes` starts from `defaultTextAttributes` — so
 `lineHeight` and `letterSpacing` reach the placeholder as well as the typed
 text. Passing only the font would lay the placeholder out on the font's own
 line height, and the text would visibly drop the moment the first character
 was typed.
 */
- (NSDictionary<NSAttributedStringKey, id> *)placeholderAttributes
{
  NSMutableDictionary<NSAttributedStringKey, id> *attributes = [[_attributes attributes] mutableCopy];
  attributes[NSForegroundColorAttributeName] = _placeholderColor ?: UIColor.placeholderTextColor;
  return attributes;
}

- (void)applyPlaceholder
{
  // Alignment rides in the paragraph style rather than `textAlignment`:
  // `UILabel` rewrites the paragraph style of its attributed text when that
  // setter is used, which would drop the line height right back out again.
  NSAttributedString *placeholder = [[NSAttributedString alloc] initWithString:_placeholder
                                                                   attributes:[self placeholderAttributes]];
  _placeholderLabel.attributedText = placeholder;
  _placeholderLabel.numberOfLines = _multiline ? 0 : 1;
  // `UITextField` has a real placeholder; `UITextView` does not, so a label is
  // overlaid for the multiline case.
  _textField.attributedPlaceholder = placeholder;
  [self setNeedsLayout];
}

- (void)applyEditable
{
  _textView.editable = _editable;
  // Selection stays available when not editable so text can still be copied,
  // matching React Native.
  _textView.selectable = YES;
  _textField.enabled = _editable;
}

- (void)applySecureTextEntry
{
  _textView.secureTextEntry = _secureTextEntry;
  _textField.secureTextEntry = _secureTextEntry;
}

- (void)applyTint
{
  UIColor *color = _caretHidden ? UIColor.clearColor : _selectionColor;
  _textView.tintColor = color;
  _textField.tintColor = color;
}

/**
 Gives a number pad the return key UIKit does not draw for it.

 A number pad has no return key at all, so without this a field using one cannot
 be dismissed from the keyboard — React Native adds the same toolbar for the
 same reason (`RCTTextInputComponentView`'s `setDefaultInputAccessoryView`).

 An `inputAccessoryViewID` takes the slot instead. What is in the slot then is
 not ours to write: the `InputAccessoryView` component assigns itself directly
 to the UIKit view, so writing here — even a nil — would take the accessory
 content back off on the next prop update. A toolbar *this* class drew earlier
 is the exception; leaving it would show the wrong bar until the component
 claims the slot, and forever if none ever does.
 */
- (void)applyDefaultInputAccessoryView
{
  if (_accessoryViewID.length > 0) {
    // A title is only held while a toolbar of ours is attached, so it is what
    // separates the two cases.
    if (_accessoryButtonTitle != nil) {
      _accessoryButtonTitle = nil;
      _textView.inputAccessoryView = nil;
      _textField.inputAccessoryView = nil;
      if ([self input].isFirstResponder) {
        [[self input] reloadInputViews];
      }
    }
    return;
  }

  BOOL hasLabel = _accessoryButtonLabel.length > 0;
  BOOL shouldHave =
      RNImeTextInputIsNumberPad(_keyboardType) && (hasLabel || RNImeTextInputReturnKeyIsLabelled(_returnKeyType));
  NSString *title = shouldHave ? (hasLabel ? _accessoryButtonLabel : RNImeTextInputReturnKeyTitle(_returnKeyType)) : nil;

  UIView *accessory = nil;
  if (title != nil) {
    UIToolbar *toolbar = [UIToolbar new];
    [toolbar sizeToFit];
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                          target:nil
                                                                          action:nil];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:title
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(handleAccessoryDoneButton)];
    toolbar.items = @[ space, done ];
    accessory = toolbar;
  }

  // Written unconditionally: `rebuildInput` hands over fresh views that need it
  // attached even when nothing about the title changed.
  _textView.inputAccessoryView = accessory;
  _textField.inputAccessoryView = accessory;

  BOOL changed = !(title == _accessoryButtonTitle || [title isEqualToString:_accessoryButtonTitle]);
  _accessoryButtonTitle = title;
  if (changed && [self input].isFirstResponder) {
    [[self input] reloadInputViews];
  }
}

- (void)handleAccessoryDoneButton
{
  if (_eventEmitter != nullptr) {
    [self emitter].onSubmit({.text = RCTStringFromNSString([self currentText])});
  }
  // The same rule the return key follows: only an explicit 'submit' keeps focus.
  if (_submitBehavior != "submit") {
    [[self input] resignFirstResponder];
  }
}

- (void)applyContextMenuHidden
{
  _textView.contextMenuHidden = _contextMenuHidden;
  _textField.contextMenuHidden = _contextMenuHidden;
}

- (void)applyAccessoryViewID
{
  _textView.inputAccessoryViewID = _accessoryViewID;
  _textField.inputAccessoryViewID = _accessoryViewID;
}

- (void)applyKeyboardTraits
{
  UITextSpellCheckingType spell;
  if (_spellCheck == "yes") {
    spell = UITextSpellCheckingTypeYes;
  } else if (_spellCheck == "no") {
    spell = UITextSpellCheckingTypeNo;
  } else {
    spell = _autoCorrect ? UITextSpellCheckingTypeDefault : UITextSpellCheckingTypeNo;
  }
  UITextAutocorrectionType correction = _autoCorrect ? UITextAutocorrectionTypeYes : UITextAutocorrectionTypeNo;

  if (_textView != nil) {
    _textView.keyboardType = _keyboardType;
    _textView.returnKeyType = _returnKeyType;
    _textView.autocapitalizationType = _autocapitalizationType;
    _textView.autocorrectionType = correction;
    _textView.spellCheckingType = spell;
    _textView.keyboardAppearance = _keyboardAppearance;
    _textView.enablesReturnKeyAutomatically = _enablesReturnKeyAutomatically;
    _textView.textContentType = _textContentType;
    _textView.smartInsertDeleteType = _smartInsertDelete;
    _textView.passwordRules = _passwordRules;
  }
  if (_textField != nil) {
    _textField.keyboardType = _keyboardType;
    _textField.returnKeyType = _returnKeyType;
    _textField.autocapitalizationType = _autocapitalizationType;
    _textField.autocorrectionType = correction;
    _textField.spellCheckingType = spell;
    _textField.keyboardAppearance = _keyboardAppearance;
    _textField.enablesReturnKeyAutomatically = _enablesReturnKeyAutomatically;
    _textField.textContentType = _textContentType;
    _textField.smartInsertDeleteType = _smartInsertDelete;
    _textField.passwordRules = _passwordRules;
    // The clear button routes through `UIControlEventEditingChanged`, the same
    // target installed in `rebuildInput`, so clearing reaches `onChangeText`
    // exactly as typing does.
    _textField.clearButtonMode = _clearButtonMode;
  }

  // Traits only take effect on a visible keyboard after a reload.
  UIView *responder = [self input];
  if (responder.isFirstResponder) {
    [responder reloadInputViews];
  }
}

#pragma mark - Selection

- (NSRange)selectionRange
{
  if (_textView != nil) {
    return _textView.selectedRange;
  }
  UITextRange *range = _textField.selectedTextRange;
  if (range == nil) {
    return NSMakeRange(0, 0);
  }
  NSInteger start = [_textField offsetFromPosition:_textField.beginningOfDocument toPosition:range.start];
  NSInteger end = [_textField offsetFromPosition:_textField.beginningOfDocument toPosition:range.end];
  return NSMakeRange((NSUInteger)start, (NSUInteger)(end - start));
}

- (void)setSelectionStart:(NSInteger)start end:(NSInteger)end
{
  NSInteger length = (NSInteger)[self currentText].length;
  NSInteger lower = MAX(0, MIN(MIN(start, end), length));
  NSInteger upper = MAX(0, MIN(MAX(start, end), length));

  if (_textView != nil) {
    _textView.selectedRange = NSMakeRange((NSUInteger)lower, (NSUInteger)(upper - lower));
    return;
  }
  UITextPosition *from = [_textField positionFromPosition:_textField.beginningOfDocument offset:lower];
  UITextPosition *to = [_textField positionFromPosition:_textField.beginningOfDocument offset:upper];
  if (from != nil && to != nil) {
    _textField.selectedTextRange = [_textField textRangeFromPosition:from toPosition:to];
  }
}

#pragma mark - Editing lifecycle shared by both backing views

- (void)handleBeganEditing
{
  if (_clearTextOnFocus) {
    [self setTextValue:@"" fromJS:YES];
  }
  if (_selectTextOnFocus) {
    [self setSelectionStart:0 end:(NSInteger)[self currentText].length];
  }
  [self emitFocus];
}

- (void)handleEndedEditing
{
  [self emitBlur];
}

/**
 Applies whatever was deferred while a conversion was open, once it commits.

 Returns whether a deferred JS text value landed. Called from the change
 delegates AND the selection-change delegates: committing a composition leaves
 the string unchanged, so `UITextField` fires no editingChanged for it — the
 caret move on commit is the only reliable signal there.
 */
- (BOOL)flushPendingAfterCommit
{
  if (_applyingFromJS || [self input].markedTextRange != nil) {
    return NO;
  }
  if (_pendingAttributeApply) {
    [self applyTextAttributes];
  }
  if (_pendingJSText == nil) {
    return NO;
  }
  NSString *pending = _pendingJSText;
  _pendingJSText = nil;
  [self setTextValue:pending fromJS:YES];
  return YES;
}

- (void)handleTextChanged
{
  // The conversion just committed, so anything deferred can land now. The
  // emit below then reports the flushed value, keeping the parent in sync.
  [self flushPendingAfterCommit];
  [self enforceMaxLength];
  [self updatePlaceholderVisibility];
  [self notifyContentSizeChange];
  [self notifySelectionChange];

  if (_applyingFromJS) {
    return;
  }
  _nativeEventCount += 1;
  [self emitChangeText];
}

/**
 Trims to `maxLength`, but never while a conversion is open — truncating
 intermediate IME output cancels the composition.
 */
/**
 Whether an over-limit replacement should be refused outright.

 Vetoing (as React Native does) keeps the caret in place and the user's trailing
 text intact; truncating after the fact would delete from the end regardless of
 where the insertion happened. Never vetoes during composition — blocking
 intermediate IME output cancels the conversion.
 */
- (BOOL)shouldAllowChangeInRange:(NSRange)range replacementText:(NSString *)text
{
  if (_maxLength <= 0 || text.length == 0 || [self input].markedTextRange != nil) {
    return YES;
  }
  NSUInteger newLength = [self currentText].length - range.length + text.length;
  return newLength <= (NSUInteger)_maxLength;
}

/**
 Post-composition backstop for text that bypassed the veto — a committed IME
 conversion, pasted marked text, dictation. Truncates on a composed-character
 boundary so surrogate pairs and combined emoji are never split in half; a lone
 surrogate would render as a broken glyph and corrupt on UTF-8 serialization.
 */
- (void)enforceMaxLength
{
  if (_maxLength <= 0 || [self input].markedTextRange != nil) {
    return;
  }
  NSString *value = [self currentText];
  NSUInteger limit = (NSUInteger)_maxLength;
  if (value.length <= limit) {
    return;
  }

  NSRange sequence = [value rangeOfComposedCharacterSequenceAtIndex:limit];
  NSUInteger cut = sequence.location < limit ? sequence.location : limit;
  NSString *truncated = [value substringToIndex:cut];
  _applyingFromJS = YES;
  if (_textView != nil) {
    _textView.text = truncated;
  } else {
    _textField.text = truncated;
  }
  _applyingFromJS = NO;
  [self setSelectionStart:(NSInteger)truncated.length end:(NSInteger)truncated.length];
}

- (void)updatePlaceholderVisibility
{
  _placeholderLabel.hidden = !_multiline || [self currentText].length > 0;
}

#pragma mark - Events

- (const RNImeTextInputEventEmitter &)emitter
{
  return static_cast<const RNImeTextInputEventEmitter &>(*_eventEmitter);
}

- (void)emitChangeText
{
  if (_eventEmitter == nullptr) {
    return;
  }
  [self emitter].onChangeText(
      {.text = RCTStringFromNSString([self currentText]), .eventCount = (int)_nativeEventCount});
}

- (void)emitFocus
{
  if (_eventEmitter == nullptr) {
    return;
  }
  [self emitter].onInputFocus({.text = RCTStringFromNSString([self currentText])});
}

- (void)emitBlur
{
  if (_eventEmitter == nullptr) {
    return;
  }
  [self emitter].onInputBlur({.text = RCTStringFromNSString([self currentText])});
}

- (void)notifySelectionChange
{
  if (_eventEmitter == nullptr) {
    return;
  }
  NSRange range = [self selectionRange];
  [self emitter].onSelectionChange(
      {.start = (int)range.location, .end = (int)(range.location + range.length)});
}

- (void)reportKeyPress:(NSString *)replacement
{
  if (_eventEmitter == nullptr) {
    return;
  }
  // React Native reports "Backspace" for deletions and "Enter" for newlines.
  NSString *key = replacement.length == 0 ? @"Backspace"
      : [replacement isEqualToString:@"\n"] ? @"Enter"
                                            : replacement;
  [self emitter].onInputKeyPress({.key = RCTStringFromNSString(key)});
}

/**
 Reports the size the text wants, so JavaScript can grow the field the way a
 React Native `TextInput` does. Only real changes are dispatched — this runs on
 every layout and keystroke.
 */
- (void)notifyContentSizeChange
{
  UIView *input = [self input];
  if (input == nil || self.bounds.size.width <= 0) {
    return;
  }
  // Measure at the width the text actually gets. The published height must be
  // the content height only: measureContent reports a content-box size and
  // Yoga adds the padding and border back on top.
  UIEdgeInsets padding = [self paddingInsets];
  CGFloat textWidth = self.bounds.size.width - _contentInsets.left - _contentInsets.right;
  if (textWidth <= 0) {
    return;
  }
  CGSize size;
  if (_textView != nil) {
    // The UITextView carries the padding as its container inset, so its own
    // sizeThatFits already includes it; measure at its frame width and strip
    // the vertical inset back out.
    CGSize fitted = [input sizeThatFits:CGSizeMake(textWidth + padding.left + padding.right,
                                                   CGFLOAT_MAX)];
    size = CGSizeMake(textWidth, fitted.height - padding.top - padding.bottom);
  } else {
    size = [input sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)];
    size.width = textWidth;
  }

  if (fabs(size.height - _lastReportedContentSize.height) <= 0.5 &&
      fabs(size.width - _lastReportedContentSize.width) <= 0.5) {
    return;
  }
  _lastReportedContentSize = size;

  // Publishing the size as state is what makes the field grow on its own: the
  // shadow node reports it from `measureContent`, so Yoga sizes the node
  // without a round trip through JavaScript. The event is still dispatched for
  // callers that ask for it, matching React Native's `onContentSizeChange`.
  if (_state != nullptr) {
    _state->updateState(RNImeTextInputStateData{facebook::react::Size{
        .width = static_cast<Float>(size.width),
        .height = static_cast<Float>(size.height),
    }});
  }

  if (_eventEmitter != nullptr) {
    [self emitter].onContentSizeChange({.width = size.width, .height = size.height});
  }
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView
{
  [self handleTextChanged];
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
  [self handleBeganEditing];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
  [self handleEndedEditing];
}

- (void)textViewDidChangeSelection:(UITextView *)textView
{
  [self notifySelectionChange];
  if ([self flushPendingAfterCommit]) {
    _nativeEventCount += 1;
    [self emitChangeText];
  }
}

- (BOOL)textView:(UITextView *)textView
    shouldChangeTextInRange:(NSRange)range
            replacementText:(NSString *)text
{
  [self reportKeyPress:text];

  // React Native's default for multiline is 'newline' (TextInput.js:572):
  // Return inserts a newline and onSubmitEditing never fires. Only an explicit
  // 'submit' or 'blurAndSubmit' turns Return into a submit action.
  if ([text isEqualToString:@"\n"] &&
      (_submitBehavior == "submit" || _submitBehavior == "blurAndSubmit")) {
    if (_eventEmitter != nullptr) {
      [self emitter].onSubmit({.text = RCTStringFromNSString([self currentText])});
    }
    if (_submitBehavior == "blurAndSubmit") {
      [[self input] resignFirstResponder];
    }
    return NO;
  }
  if (![self shouldAllowChangeInRange:range replacementText:text]) {
    return NO;
  }
  return YES;
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidChange
{
  [self handleTextChanged];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
  [self handleBeganEditing];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
  [self handleEndedEditing];
}

- (void)textFieldDidChangeSelection:(UITextField *)textField
{
  [self notifySelectionChange];
  if ([self flushPendingAfterCommit]) {
    _nativeEventCount += 1;
    [self emitChangeText];
  }
}

- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)string
{
  [self reportKeyPress:string];
  return [self shouldAllowChangeInRange:range replacementText:string];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
  if (_eventEmitter != nullptr) {
    [self emitter].onSubmit({.text = RCTStringFromNSString([self currentText])});
  }
  // Single-line default is 'blurAndSubmit'; only an explicit 'submit' keeps
  // focus. 'newline' is meaningless here and falls back to the default.
  if (_submitBehavior != "submit") {
    [textField resignFirstResponder];
  }
  return NO;
}

#pragma mark - Fabric

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &newProps = static_cast<const RNImeTextInputProps &>(*props);
  const RNImeTextInputProps *old = oldProps ? &static_cast<const RNImeTextInputProps &>(*oldProps) : nullptr;

  // Multiline first: it rebuilds the backing view, and everything below has to
  // land on the new one.
  //
  // The comparison is against what is currently *built*, not against the old
  // props: the initializer has to pick one kind before any props arrive, so on
  // the first update the old props are null while the wrong view may already be
  // in place.
  if (old == nullptr || newProps.multiline != old->multiline) {
    _multiline = newProps.multiline;
    BOOL builtMultiline = _textView != nil;
    if (builtMultiline != _multiline) {
      [self rebuildInput];
    }
  }

  // Read before the attributes are built: the multiplier below depends on them.
  _allowFontScaling = newProps.allowFontScaling;
  _maxFontSizeMultiplier = newProps.maxFontSizeMultiplier;

  RNImeTextInputAttributes *attributes = [_attributes copy];
  attributes.fontSize = newProps.fontSize > 0 ? newProps.fontSize : 17;
  attributes.fontSizeMultiplier = [self currentFontSizeMultiplier];
  attributes.fontWeight = RNImeTextInputFontWeight(newProps.fontWeight);
  attributes.fontFamily = RCTNSStringFromStringNilIfEmpty(newProps.fontFamily);
  attributes.italic = newProps.fontStyle == "italic";
  attributes.color = RCTUIColorFromSharedColor(newProps.color);
  attributes.textAlign = RNImeTextInputAlignment(newProps.textAlign);
  attributes.lineHeight = newProps.lineHeight;
  attributes.letterSpacing = newProps.letterSpacing;
  attributes.underline =
      newProps.textDecorationLine == "underline" || newProps.textDecorationLine == "underline line-through";
  attributes.strikethrough =
      newProps.textDecorationLine == "line-through" || newProps.textDecorationLine == "underline line-through";
  attributes.decorationColor = RCTUIColorFromSharedColor(newProps.textDecorationColor);
  attributes.decorationStyle = RNImeTextInputUnderlineStyle(newProps.textDecorationStyle);
  attributes.shadowColor = RCTUIColorFromSharedColor(newProps.textShadowColor);
  attributes.shadowOffset = CGSizeMake(newProps.textShadowOffsetWidth, newProps.textShadowOffsetHeight);
  attributes.shadowRadius = newProps.textShadowRadius;
  attributes.writingDirection = RNImeTextInputWritingDirection(newProps.writingDirection);

  if (![attributes isEqualToAttributes:_attributes]) {
    _attributes = attributes;
    [self applyTextAttributes];
    [self applyPlaceholder];
  }

  if (old == nullptr || newProps.placeholder != old->placeholder ||
      newProps.placeholderTextColor != old->placeholderTextColor) {
    _placeholder = RCTNSStringFromString(newProps.placeholder);
    _placeholderColor = RCTUIColorFromSharedColor(newProps.placeholderTextColor);
    [self applyPlaceholder];
  }

  if (old == nullptr || newProps.editable != old->editable) {
    _editable = newProps.editable;
    [self applyEditable];
  }

  if (old == nullptr || newProps.secureTextEntry != old->secureTextEntry) {
    _secureTextEntry = newProps.secureTextEntry;
    [self applySecureTextEntry];
  }

  if (old == nullptr || newProps.caretHidden != old->caretHidden ||
      newProps.selectionColor != old->selectionColor) {
    _caretHidden = newProps.caretHidden;
    _selectionColor = RCTUIColorFromSharedColor(newProps.selectionColor);
    [self applyTint];
  }

  if (old == nullptr || newProps.contextMenuHidden != old->contextMenuHidden) {
    _contextMenuHidden = newProps.contextMenuHidden;
    [self applyContextMenuHidden];
  }

  if (old == nullptr || newProps.keyboardType != old->keyboardType ||
      newProps.returnKeyType != old->returnKeyType || newProps.autoCapitalize != old->autoCapitalize ||
      newProps.autoCorrect != old->autoCorrect || newProps.spellCheck != old->spellCheck ||
      newProps.keyboardAppearance != old->keyboardAppearance ||
      newProps.enablesReturnKeyAutomatically != old->enablesReturnKeyAutomatically ||
      newProps.textContentType != old->textContentType ||
      newProps.smartInsertDelete != old->smartInsertDelete || newProps.passwordRules != old->passwordRules ||
      newProps.clearButtonMode != old->clearButtonMode ||
      newProps.inputAccessoryViewButtonLabel != old->inputAccessoryViewButtonLabel ||
      newProps.inputAccessoryViewID != old->inputAccessoryViewID) {
    _keyboardType = RNImeTextInputKeyboardType(newProps.keyboardType);
    _returnKeyType = RNImeTextInputReturnKeyType(newProps.returnKeyType);
    _autocapitalizationType = RNImeTextInputAutocapitalization(newProps.autoCapitalize);
    _autoCorrect = newProps.autoCorrect;
    _spellCheck = newProps.spellCheck;
    _keyboardAppearance = RNImeTextInputKeyboardAppearance(newProps.keyboardAppearance);
    _enablesReturnKeyAutomatically = newProps.enablesReturnKeyAutomatically;
    // RN's token vocabulary ("emailAddress", "oneTimeCode", ...) parsed the
    // same way core does — a raw token like "email" is not a valid
    // UITextContentType and silently disables autofill.
    _textContentType = newProps.textContentType.empty()
        ? nil
        : RCTUITextContentTypeFromString(newProps.textContentType);
    _smartInsertDelete = RNImeTextInputSmartInsertDelete(newProps.smartInsertDelete);
    // An empty descriptor produces a rules object that suppresses the
    // strong-password suggestion, so "none given" has to stay nil.
    _passwordRules = newProps.passwordRules.empty()
        ? nil
        : [UITextInputPasswordRules passwordRulesWithDescriptor:RCTNSStringFromString(newProps.passwordRules)];
    _clearButtonMode = RNImeTextInputViewMode(newProps.clearButtonMode);
    _accessoryButtonLabel = RCTNSStringFromString(newProps.inputAccessoryViewButtonLabel);
    _accessoryViewID = RCTNSStringFromStringNilIfEmpty(newProps.inputAccessoryViewID);
    [self applyKeyboardTraits];
    [self applyAccessoryViewID];
    // Depends on the keyboard and return key just applied, so it follows them.
    [self applyDefaultInputAccessoryView];
  }

  _maxLength = newProps.maxLength;
  _autoFocus = newProps.autoFocus;
  _selectTextOnFocus = newProps.selectTextOnFocus;
  _clearTextOnFocus = newProps.clearTextOnFocus;
  _submitBehavior = newProps.submitBehavior.empty() ? "default" : newProps.submitBehavior;

  _mostRecentEventCount = newProps.mostRecentEventCount;

  // Text last, so it lands on a fully configured view. The revision is what
  // makes a refused edit revert — see the prop's comment in the spec.
  //
  // `mostRecentEventCount` is deliberately NOT an application trigger, only a
  // staleness guard inside applyJSText. It changes on every native edit, so
  // treating it as a trigger would re-assert the (unchanged) `text` prop after
  // each keystroke — for an uncontrolled field that is the mount-time initial
  // value, and re-applying it rolls back whatever the user has typed.
  if (old == nullptr || newProps.text != old->text || newProps.textRevision != old->textRevision) {
    _jsText = RCTNSStringFromString(newProps.text);
    [self applyJSText];
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)updateState:(const State::Shared &)state oldState:(const State::Shared &)oldState
{
  _state = std::static_pointer_cast<const RNImeTextInputShadowNodeImpl::ConcreteState>(state);
  [super updateState:state oldState:oldState];
}

- (void)prepareForRecycle
{
  [super prepareForRecycle];
  _state.reset();
  _pendingJSText = nil;
  _nativeEventCount = 0;
  _mostRecentEventCount = 0;
  _contentInsets = UIEdgeInsetsZero;
  _borderInsets = UIEdgeInsetsZero;
  _jsText = nil;
  _applyingFromJS = NO;
  _pendingAttributeApply = NO;
  _didAutoFocus = NO;
  _lastReportedContentSize = CGSizeZero;
  // A recycled view keeps its backing views, so the toolbar has to be taken off
  // explicitly — the next mount may not want one.
  _accessoryButtonLabel = nil;
  _accessoryButtonTitle = nil;
  _accessoryViewID = nil;
  _textView.inputAccessoryView = nil;
  _textField.inputAccessoryView = nil;
  // Left behind, a stale id would let the next `InputAccessoryView` claim a
  // field that no longer asked for one.
  _textView.inputAccessoryViewID = nil;
  _textField.inputAccessoryViewID = nil;
  [self setTextValue:@"" fromJS:YES];
}

#pragma mark - Commands

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args
{
  RCTRNImeTextInputHandleCommand(self, commandName, args);
}

- (void)focus
{
  [[self input] becomeFirstResponder];
}

- (void)blur
{
  [[self input] resignFirstResponder];
}

- (void)clear
{
  if ([self input].markedTextRange != nil) {
    // Mid-composition the buffer must not be touched; the clear lands when the
    // conversion commits, and handleTextChanged emits the (then empty) text.
    // Emitting now would report the stale draft as if it survived the clear.
    _pendingJSText = @"";
    return;
  }
  [self setTextValue:@"" fromJS:YES];
  [self emitChangeText];
}

- (void)setSelection:(NSInteger)start end:(NSInteger)end
{
  [self setSelectionStart:start end:end];
}

@end

Class<RCTComponentViewProtocol> RNImeTextInputCls(void)
{
  return RNImeTextInput.class;
}

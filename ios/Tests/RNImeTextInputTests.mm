#import <XCTest/XCTest.h>

#import <react/renderer/components/RNImeTextInputSpec/Props.h>

#import "RNImeTextInput.h"

using namespace facebook::react;

/**
 The internals under test. Declared here rather than in a shipped header so the
 library's public surface stays as small as it is — and so a rename shows up as
 a compile error in the tests that depend on it.
 */
@interface RNImeTextInput (Testing)
- (UIView<UITextInput> *)input;
- (NSString *)currentText;
- (void)setTextValue:(NSString *)newValue fromJS:(BOOL)fromJS;
- (void)handleTextChanged;
- (void)commitComposition;
- (NSInteger)nativeEventCount;
- (void)enforceMaxLength;
- (CGFloat)fontSizeMultiplierForContentSizeCategory:(UIContentSizeCategory)category;
- (CGFloat)effectiveFontSizeMultiplierForBase:(CGFloat)base;
- (void)contentSizeCategoryDidChange;
@end

/**
 The invariants that keep IME composition alive.

 These are the reason the library exists, and until now they were only ever
 checked by hand with a Japanese keyboard. A conversion can be staged
 programmatically — `setMarkedText:selectedRange:` is what the keyboard itself
 calls — so the rules can be asserted without one.
 */
@interface RNImeTextInputTests : XCTestCase
@end

/**
 The props the view is currently holding.
 *
 * `RNImeTextInputProps` cannot be copied, so each update is built from these
 * accumulated values rather than from the previous props object — which also
 * keeps the two objects distinct, as the mounting layer's diffing expects.
 */
struct TestProps {
  bool multiline = true;
  std::string text;
  std::string placeholder;
  int textRevision = 0;
  int mostRecentEventCount = 0;
  int maxLength = 0;
  double fontSize = 17;
  double lineHeight = 0;
  double letterSpacing = 0;
  std::string textDecorationLine;
  std::string smartInsertDelete;
  std::string passwordRules;
  std::string clearButtonMode;
  bool contextMenuHidden = false;
  std::string keyboardType;
  std::string returnKeyType;
  std::string submitBehavior;
  std::string inputAccessoryViewButtonLabel;
  bool allowFontScaling = true;
  double maxFontSizeMultiplier = 0;
  std::string inputAccessoryViewID;
};

@implementation RNImeTextInputTests {
  RNImeTextInput *_view;
  TestProps _values;
  std::shared_ptr<const RNImeTextInputProps> _props;
  /// Only set by the tests that need a live responder; see `activateWithText:`.
  UIWindow *_window;
}

- (void)setUp
{
  [super setUp];
  _view = [[RNImeTextInput alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
  _values = TestProps{};
  _props = nullptr;
  [self applyProps:^(TestProps &values) {
  }];
}

- (void)tearDown
{
  // A key window outliving its test would keep the next test's field from
  // becoming first responder.
  [[_view input] resignFirstResponder];
  _window.hidden = YES;
  _window = nil;
  [super tearDown];
}

/** Pushes a prop change through the same path the mounting layer uses. */
- (void)applyProps:(void (^)(TestProps &))mutate
{
  mutate(_values);

  auto next = std::make_shared<RNImeTextInputProps>();
  next->multiline = _values.multiline;
  next->text = _values.text;
  next->placeholder = _values.placeholder;
  next->textRevision = _values.textRevision;
  next->mostRecentEventCount = _values.mostRecentEventCount;
  next->maxLength = _values.maxLength;
  next->fontSize = _values.fontSize;
  next->lineHeight = _values.lineHeight;
  next->letterSpacing = _values.letterSpacing;
  next->textDecorationLine = _values.textDecorationLine;
  next->smartInsertDelete = _values.smartInsertDelete;
  next->passwordRules = _values.passwordRules;
  next->clearButtonMode = _values.clearButtonMode;
  next->contextMenuHidden = _values.contextMenuHidden;
  next->keyboardType = _values.keyboardType;
  next->returnKeyType = _values.returnKeyType;
  next->submitBehavior = _values.submitBehavior;
  next->inputAccessoryViewButtonLabel = _values.inputAccessoryViewButtonLabel;
  next->allowFontScaling = _values.allowFontScaling;
  next->maxFontSizeMultiplier = _values.maxFontSizeMultiplier;
  next->inputAccessoryViewID = _values.inputAccessoryViewID;

  [_view updateProps:next oldProps:_props];
  _props = next;
}

/** Stages an open conversion, exactly as the keyboard does mid-input. */
- (void)beginComposing:(NSString *)marked
{
  UIView<UITextInput> *input = [_view input];
  [input setMarkedText:marked selectedRange:NSMakeRange(marked.length, 0)];
  XCTAssertNotNil(input.markedTextRange, @"the conversion did not start");
}

/** Commits it as the keyboard would, and runs the callback the delegate would. */
- (void)commitCompositionFromKeyboard
{
  [[_view input] unmarkText];
  [_view handleTextChanged];
}

#pragma mark - Rule 1: the buffer is never rewritten mid-conversion

- (void)testAValueFromJavaScriptDoesNotCancelAnOpenConversion
{
  [self beginComposing:@"にほんご"];

  [_view setTextValue:@"replaced" fromJS:YES];

  XCTAssertNotNil([_view input].markedTextRange, @"the underline would be gone");
  XCTAssertEqualObjects([_view currentText], @"にほんご");
}

- (void)testTheHeldValueLandsOnceTheConversionCommits
{
  [self beginComposing:@"にほんご"];
  [_view setTextValue:@"replaced" fromJS:YES];

  [self commitCompositionFromKeyboard];

  // Dropping it instead would leave the field permanently out of step with the
  // parent that asked for it.
  XCTAssertEqualObjects([_view currentText], @"replaced");
}

- (void)testAPropUpdateDoesNotCancelAnOpenConversionEither
{
  [self beginComposing:@"かんじ"];

  [self applyProps:^(TestProps &props) {
    props.text = "from the parent";
    props.textRevision = 1;
    props.mostRecentEventCount = 0;
  }];

  XCTAssertNotNil([_view input].markedTextRange);
  XCTAssertEqualObjects([_view currentText], @"かんじ");
}

#pragma mark - commitComposition

- (void)testCommitCompositionEndsTheConversion
{
  [self beginComposing:@"あかさ"];

  [_view commitComposition];

  XCTAssertNil([_view input].markedTextRange);
  // `unmarkText` confirms what is on screen as it stands; it does not convert.
  XCTAssertEqualObjects([_view currentText], @"あかさ");
}

- (void)testCommitCompositionLetsAnInsertionFromJavaScriptLand
{
  // The reason the command exists: an emoji bar tapped mid-conversion used to be
  // held back and then applied on commit, overwriting the conversion result.
  [self beginComposing:@"あかさ"];

  [_view commitComposition];
  [_view setTextValue:@"あかさ😄" fromJS:YES];

  XCTAssertEqualObjects([_view currentText], @"あかさ😄");
}

- (void)testCommitCompositionFlushesAValueTheConversionWasHolding
{
  [self beginComposing:@"あかさ"];
  [_view setTextValue:@"replaced" fromJS:YES];

  [_view commitComposition];

  XCTAssertEqualObjects([_view currentText], @"replaced");
}

- (void)testCommitCompositionAppliesMaxLengthTheConversionHeldBack
{
  [self applyProps:^(TestProps &props) {
    props.maxLength = 3;
  }];
  [self beginComposing:@"にほんごにゅうりょく"];

  [_view commitComposition];

  XCTAssertEqualObjects([_view currentText], @"にほん");
}

- (void)testCommitCompositionIsNotReportedAsAUserEdit
{
  // Composing reports change events, and JavaScript echoes back the count it
  // has seen; here it is in sync, as it is by the time a button is tapped.
  [self beginComposing:@"ろうそく"];
  NSInteger seenByJavaScript = [_view nativeEventCount];

  [_view commitComposition];

  // UIKit reports the unmark as an edit. Passing that on would outrun what
  // JavaScript has seen, and the value it sends next — the one this call is
  // clearing the way for — would be refused as stale.
  XCTAssertEqual([_view nativeEventCount], seenByJavaScript);

  // The real path: the insertion arrives as a prop, carrying that same count.
  [self applyProps:^(TestProps &props) {
    props.text = "ろうそく😄";
    props.textRevision = 1;
    props.mostRecentEventCount = (int)seenByJavaScript;
  }];

  XCTAssertEqualObjects([_view currentText], @"ろうそく😄");
}

- (void)testCommitCompositionDoesNothingWhenNoConversionIsOpen
{
  [_view setTextValue:@"plain" fromJS:YES];

  [_view commitComposition];

  XCTAssertNil([_view input].markedTextRange);
  XCTAssertEqualObjects([_view currentText], @"plain");
}

#pragma mark - Rule 2: attributes are never written mid-conversion

- (void)testAnAttributeChangeDoesNotCancelAnOpenConversion
{
  [self beginComposing:@"にほんご"];

  [self applyProps:^(TestProps &props) {
    props.fontSize = 24;
    props.lineHeight = 32;
    props.letterSpacing = 2;
    props.textDecorationLine = "underline";
  }];

  XCTAssertNotNil([_view input].markedTextRange, @"attributes were written mid-conversion");
  XCTAssertEqualObjects([_view currentText], @"にほんご");
}

- (void)testTheHeldAttributesLandOnceTheConversionCommits
{
  [self beginComposing:@"にほんご"];
  [self applyProps:^(TestProps &props) {
    props.fontSize = 24;
  }];

  [self commitCompositionFromKeyboard];

  UITextView *textView = (UITextView *)[_view input];
  XCTAssertEqual(textView.font.pointSize, 24);
}

#pragma mark - maxLength

- (void)testMaxLengthDoesNotTruncateAnOpenConversion
{
  [self applyProps:^(TestProps &props) {
    props.maxLength = 3;
  }];
  [self beginComposing:@"にほんごにゅうりょく"];

  [_view enforceMaxLength];

  XCTAssertEqualObjects([_view currentText], @"にほんごにゅうりょく");
  XCTAssertNotNil([_view input].markedTextRange);
}

- (void)testMaxLengthAppliesOnceTheConversionCommits
{
  [self applyProps:^(TestProps &props) {
    props.maxLength = 3;
  }];
  [self beginComposing:@"にほんごにゅうりょく"];

  [self commitCompositionFromKeyboard];

  XCTAssertEqualObjects([_view currentText], @"にほん");
}

- (void)testMaxLengthCutsOnAComposedCharacterBoundary
{
  [self applyProps:^(TestProps &props) {
    props.maxLength = 3;
  }];

  // A family emoji is a single grapheme spanning 11 UTF-16 units. Cutting at
  // index 3 would leave half a surrogate pair, which renders as a broken glyph
  // and corrupts when serialised.
  [_view setTextValue:@"👨‍👩‍👧‍👦abc" fromJS:NO];
  [_view enforceMaxLength];

  // The grapheme starts before the limit and runs past it, so there is no cut
  // that keeps it whole — leaving nothing beats leaving half a surrogate pair.
  XCTAssertEqualObjects([_view currentText], @"");
}

- (void)testMaxLengthLeavesShorterTextAlone
{
  [self applyProps:^(TestProps &props) {
    props.maxLength = 10;
  }];

  [_view setTextValue:@"abc" fromJS:NO];
  [_view enforceMaxLength];

  XCTAssertEqualObjects([_view currentText], @"abc");
}

#pragma mark - The staleness guard

- (void)testAValueThatPredatesTheLatestKeystrokeIsRefused
{
  // A user edit the parent has not seen yet.
  [_view setTextValue:@"typed" fromJS:NO];
  [_view handleTextChanged];

  // The parent answers the *previous* event, so its value is already behind.
  [self applyProps:^(TestProps &props) {
    props.text = "stale";
    props.textRevision = 1;
    props.mostRecentEventCount = 0;
  }];

  XCTAssertEqualObjects([_view currentText], @"typed", @"the field would rewind and flicker");
}

- (void)testAValueThatAnswersTheLatestKeystrokeIsApplied
{
  [_view setTextValue:@"typed" fromJS:NO];
  [_view handleTextChanged];

  [self applyProps:^(TestProps &props) {
    props.text = "accepted";
    props.textRevision = 1;
    props.mostRecentEventCount = 1;
  }];

  XCTAssertEqualObjects([_view currentText], @"accepted");
}

#pragma mark - Backing views

- (void)testAMultilineFieldIsBackedByATextView
{
  XCTAssertTrue([[_view input] isKindOfClass:[UITextView class]]);
}

- (void)testASingleLineFieldIsBackedByATextField
{
  [self applyProps:^(TestProps &props) {
    props.multiline = false;
  }];

  XCTAssertTrue([[_view input] isKindOfClass:[UITextField class]]);
}

- (void)testSwitchingToMultilineCarriesTheTextAcross
{
  [self applyProps:^(TestProps &props) {
    props.multiline = false;
  }];
  [_view setTextValue:@"carried" fromJS:NO];

  [self applyProps:^(TestProps &props) {
    props.multiline = true;
  }];

  XCTAssertTrue([[_view input] isKindOfClass:[UITextView class]]);
  XCTAssertEqualObjects([_view currentText], @"carried");
}

#pragma mark - Input traits

/** Switches to the single-line backing view and hands it back. */
- (UITextField *)textFieldWith:(void (^)(TestProps &))mutate
{
  [self applyProps:^(TestProps &props) {
    props.multiline = false;
    mutate(props);
  }];
  return (UITextField *)[_view input];
}

- (void)testClearButtonModeReachesTheTextField
{
  UITextField *field = [self textFieldWith:^(TestProps &props) {
    props.clearButtonMode = "unless-editing";
  }];

  XCTAssertEqual(field.clearButtonMode, UITextFieldViewModeUnlessEditing);
}

- (void)testAnUnsetClearButtonModeLeavesTheButtonHidden
{
  UITextField *field = [self textFieldWith:^(TestProps &props) {
  }];

  XCTAssertEqual(field.clearButtonMode, UITextFieldViewModeNever);
}

- (void)testPasswordRulesReachTheTextField
{
  UITextField *field = [self textFieldWith:^(TestProps &props) {
    props.passwordRules = "minlength: 8;";
  }];

  XCTAssertEqualObjects(field.passwordRules.passwordRulesDescriptor, @"minlength: 8;");
}

- (void)testAnEmptyPasswordRulesDescriptorLeavesTheTraitUnset
{
  // `passwordRulesWithDescriptor:` on an empty string produces a rules object
  // that suppresses the strong-password suggestion — not the same as none.
  UITextField *field = [self textFieldWith:^(TestProps &props) {
  }];

  XCTAssertNil(field.passwordRules);
}

- (void)testSmartInsertDeleteCanBeTurnedOff
{
  UITextField *field = [self textFieldWith:^(TestProps &props) {
    props.smartInsertDelete = "no";
  }];

  XCTAssertEqual(field.smartInsertDeleteType, UITextSmartInsertDeleteTypeNo);
}

- (void)testSmartInsertDeleteReachesTheMultilineViewToo
{
  // Both backing views are configured from the same place; a trait written to
  // only one branch is the mistake this catches.
  [self applyProps:^(TestProps &props) {
    props.smartInsertDelete = "no";
  }];

  XCTAssertEqual(((UITextView *)[_view input]).smartInsertDeleteType, UITextSmartInsertDeleteTypeNo);
}

- (void)testAnUnsetSmartInsertDeleteLeavesUIKitsDefault
{
  UITextField *field = [self textFieldWith:^(TestProps &props) {
  }];

  XCTAssertEqual(field.smartInsertDeleteType, UITextSmartInsertDeleteTypeDefault);
}

#pragma mark - The edit menu

/**
 Puts the field on screen and makes it first responder.

 `canPerformAction:` is not a pure function of the view: a detached, unfocused
 text view answers NO to everything, which would make every assertion below pass
 without an implementation. Editing has to actually be possible for the question
 to mean anything.
 */
- (void)activateWithText:(NSString *)text
{
  [_view setTextValue:text fromJS:NO];
  _window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
  [_window addSubview:_view];
  [_window makeKeyAndVisible];
  XCTAssertTrue([[_view input] becomeFirstResponder], @"the field never became editable");
}

- (void)testTheEditMenuIsLeftToUIKitByDefault
{
  [self activateWithText:@"copyable"];

  XCTAssertTrue([(UIResponder *)[_view input] canPerformAction:@selector(selectAll:) withSender:nil]);
}

- (void)testAHiddenEditMenuRefusesEveryAction
{
  [self applyProps:^(TestProps &props) {
    props.contextMenuHidden = true;
  }];

  [self activateWithText:@"copyable"];

  UIResponder *input = (UIResponder *)[_view input];
  XCTAssertFalse([input canPerformAction:@selector(selectAll:) withSender:nil]);
  XCTAssertFalse([input canPerformAction:@selector(copy:) withSender:nil]);
  XCTAssertFalse([input canPerformAction:@selector(paste:) withSender:nil]);
}

- (void)testAHiddenEditMenuSurvivesSwitchingBackingViews
{
  [self applyProps:^(TestProps &props) {
    props.contextMenuHidden = true;
  }];

  // Covers the single-line branch and the rebuild path at once: switching views
  // throws the configured instance away and builds a fresh one.
  [self applyProps:^(TestProps &props) {
    props.multiline = false;
  }];
  [self activateWithText:@"copyable"];

  XCTAssertFalse([(UIResponder *)[_view input] canPerformAction:@selector(selectAll:) withSender:nil]);
}

#pragma mark - The default input accessory view

/**
 A number pad has no return key, so React Native gives it a toolbar carrying one
 — otherwise the keyboard cannot be dismissed from the keyboard at all. Mirrors
 `RCTTextInputComponentView`'s `setDefaultInputAccessoryView`.
 */
- (UIToolbar *)accessoryToolbar
{
  return (UIToolbar *)[[_view input] inputAccessoryView];
}

- (UIBarButtonItem *)accessoryButton
{
  return [self accessoryToolbar].items.lastObject;
}

- (void)testANumberPadGetsAToolbarTitledAfterItsReturnKey
{
  [self applyProps:^(TestProps &props) {
    props.keyboardType = "number-pad";
    props.returnKeyType = "search";
  }];

  XCTAssertTrue([[self accessoryToolbar] isKindOfClass:[UIToolbar class]]);
  XCTAssertEqualObjects([self accessoryButton].title, @"Search");
}

- (void)testAKeyboardThatAlreadyHasAReturnKeyGetsNoToolbar
{
  [self applyProps:^(TestProps &props) {
    props.returnKeyType = "done";
  }];

  XCTAssertNil([[_view input] inputAccessoryView]);
}

- (void)testANumberPadWithNoReturnKeyTypeGetsNoToolbar
{
  // Nothing to label the button with, and React Native adds none either.
  [self applyProps:^(TestProps &props) {
    props.keyboardType = "number-pad";
  }];

  XCTAssertNil([[_view input] inputAccessoryView]);
}

- (void)testAnAccessoryButtonLabelIsEnoughOnItsOwn
{
  [self applyProps:^(TestProps &props) {
    props.keyboardType = "decimal-pad";
    props.inputAccessoryViewButtonLabel = "完了";
  }];

  XCTAssertEqualObjects([self accessoryButton].title, @"完了");
}

- (void)testTheToolbarGoesAwayWhenTheKeyboardStopsBeingANumberPad
{
  [self applyProps:^(TestProps &props) {
    props.keyboardType = "number-pad";
    props.returnKeyType = "done";
  }];

  [self applyProps:^(TestProps &props) {
    props.keyboardType = "";
  }];

  XCTAssertNil([[_view input] inputAccessoryView]);
}

- (void)testTheToolbarSurvivesSwitchingBackingViews
{
  [self applyProps:^(TestProps &props) {
    props.keyboardType = "number-pad";
    props.returnKeyType = "done";
  }];

  [self applyProps:^(TestProps &props) {
    props.multiline = false;
  }];

  XCTAssertEqualObjects([self accessoryButton].title, @"Done");
}

- (void)testTheToolbarButtonDismissesTheKeyboard
{
  [self applyProps:^(TestProps &props) {
    props.keyboardType = "number-pad";
    props.returnKeyType = "done";
  }];
  [self activateWithText:@"1234"];

  UIBarButtonItem *done = [self accessoryButton];
  XCTAssertNotNil(done, @"there was no button to press");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  [done.target performSelector:done.action withObject:done];
#pragma clang diagnostic pop

  XCTAssertFalse([[_view input] isFirstResponder]);
}

- (void)testTheToolbarButtonKeepsFocusWhenSubmitBehaviourSaysSo
{
  [self applyProps:^(TestProps &props) {
    props.keyboardType = "number-pad";
    props.returnKeyType = "done";
    props.submitBehavior = "submit";
  }];
  [self activateWithText:@"1234"];

  UIBarButtonItem *done = [self accessoryButton];
  XCTAssertNotNil(done, @"there was no button to press");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  [done.target performSelector:done.action withObject:done];
#pragma clang diagnostic pop

  XCTAssertTrue([[_view input] isFirstResponder]);
}

#pragma mark - InputAccessoryView

/**
 React Native's own discovery predicate, from `RCTInputAccessoryComponentView`'s
 `RCTFindTextInputWithNativeId` (lines 23-41). It walks the window and matches
 on duck typing alone — a view that answers to `inputAccessoryViewID` and
 `setInputAccessoryView:` and carries the right id. Reproduced rather than
 mocked, because satisfying exactly this is the whole contract: nothing else in
 this library reads the prop back.
 */
- (BOOL)isFoundByAnInputAccessoryViewWithID:(NSString *)nativeID
{
  UIView *view = (UIView *)[_view input];
  if (![view respondsToSelector:@selector(inputAccessoryViewID)] ||
      ![view respondsToSelector:@selector(setInputAccessoryView:)]) {
    return NO;
  }
  return [[view valueForKey:@"inputAccessoryViewID"] isEqualToString:nativeID];
}

- (void)testTheFieldIsFoundByAnInputAccessoryViewCarryingTheSameID
{
  [self applyProps:^(TestProps &props) {
    props.inputAccessoryViewID = "composer";
  }];

  XCTAssertTrue([self isFoundByAnInputAccessoryViewWithID:@"composer"]);
}

- (void)testTheFieldIsNotFoundByAnInputAccessoryViewWithADifferentID
{
  [self applyProps:^(TestProps &props) {
    props.inputAccessoryViewID = "composer";
  }];

  XCTAssertFalse([self isFoundByAnInputAccessoryViewWithID:@"somethingElse"]);
}

- (void)testTheIDSurvivesSwitchingBackingViews
{
  [self applyProps:^(TestProps &props) {
    props.inputAccessoryViewID = "composer";
  }];

  [self applyProps:^(TestProps &props) {
    props.multiline = false;
  }];

  XCTAssertTrue([self isFoundByAnInputAccessoryViewWithID:@"composer"]);
}

- (void)testAnIDSuppressesTheDefaultNumberPadToolbar
{
  // React Native returns early from `setDefaultInputAccessoryView` for the same
  // reason: the `InputAccessoryView` component owns the slot, and a toolbar
  // written here would take it from under the accessory content.
  [self applyProps:^(TestProps &props) {
    props.keyboardType = "number-pad";
    props.returnKeyType = "done";
    props.inputAccessoryViewID = "composer";
  }];

  XCTAssertNil([[_view input] inputAccessoryView]);
}

- (void)testAnAccessoryViewAssignedFromOutsideIsNotClobbered
{
  [self applyProps:^(TestProps &props) {
    props.inputAccessoryViewID = "composer";
  }];
  UIView *content = [UIView new];
  // What React Native's component does once it has found the field.
  ((UITextView *)[_view input]).inputAccessoryView = content;

  [self applyProps:^(TestProps &props) {
    props.keyboardType = "number-pad";
    props.returnKeyType = "done";
  }];

  XCTAssertEqualObjects(((UITextView *)[_view input]).inputAccessoryView, content);
}

- (void)testAToolbarThisFieldDrewIsTakenBackOffWhenAnIDArrives
{
  [self applyProps:^(TestProps &props) {
    props.keyboardType = "number-pad";
    props.returnKeyType = "done";
  }];
  XCTAssertNotNil([[_view input] inputAccessoryView], @"there was no toolbar to take off");

  [self applyProps:^(TestProps &props) {
    props.inputAccessoryViewID = "composer";
  }];

  // Stepping aside for an `InputAccessoryView` means leaving *its* accessory
  // alone, not leaving a toolbar of ours in the slot it is about to claim.
  XCTAssertNil([[_view input] inputAccessoryView]);
}

- (void)testAnAccessoryViewAssignedFromOutsideSurvivesSwitchingBackingViews
{
  [self applyProps:^(TestProps &props) {
    props.inputAccessoryViewID = "composer";
  }];
  UIView *content = [UIView new];
  ((UITextView *)[_view input]).inputAccessoryView = content;

  [self applyProps:^(TestProps &props) {
    props.multiline = false;
  }];

  // React Native's component resolves its field once, in `didMoveToWindow`, so
  // a backing view that comes up without the accessory never gets it back — the
  // bar is gone for the rest of the session. Core carries it across the same
  // switch (`RCTTextInputUtils.mm`'s `RCTCopyBackedTextInput`, line 29).
  XCTAssertEqualObjects(((UITextField *)[_view input]).inputAccessoryView, content);
}

#pragma mark - Dynamic Type

- (void)testTheSystemTextSizeBecomesAMultiplier
{
  XCTAssertEqualWithAccuracy([_view fontSizeMultiplierForContentSizeCategory:UIContentSizeCategoryLarge], 1.0, 0.001);
  XCTAssertEqualWithAccuracy(
      [_view fontSizeMultiplierForContentSizeCategory:UIContentSizeCategoryExtraSmall], 0.823, 0.001);
  XCTAssertEqualWithAccuracy(
      [_view fontSizeMultiplierForContentSizeCategory:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge],
      3.571,
      0.001);
}

- (void)testAnUnspecifiedTextSizeMeansNoScaling
{
  // A view that is not in a hierarchy yet reports `unspecified`. React Native
  // reads its table with that key and gets 0 back, which would resolve to a
  // zero-point font; a missing entry has to mean "no scaling" instead.
  XCTAssertEqualWithAccuracy(
      [_view fontSizeMultiplierForContentSizeCategory:UIContentSizeCategoryUnspecified], 1.0, 0.001);
}

- (void)testScalingIsRefusedWhenAllowFontScalingIsOff
{
  [self applyProps:^(TestProps &props) {
    props.allowFontScaling = false;
  }];

  XCTAssertEqualWithAccuracy([_view effectiveFontSizeMultiplierForBase:1.5], 1.0, 0.001);
}

- (void)testScalingIsUncappedByDefault
{
  XCTAssertEqualWithAccuracy([_view effectiveFontSizeMultiplierForBase:3.571], 3.571, 0.001);
}

- (void)testMaxFontSizeMultiplierCapsTheScaling
{
  [self applyProps:^(TestProps &props) {
    props.maxFontSizeMultiplier = 1.2;
  }];

  XCTAssertEqualWithAccuracy([_view effectiveFontSizeMultiplierForBase:1.5], 1.2, 0.001);
}

- (void)testACapAboveTheSystemScaleChangesNothing
{
  [self applyProps:^(TestProps &props) {
    props.maxFontSizeMultiplier = 2;
  }];

  XCTAssertEqualWithAccuracy([_view effectiveFontSizeMultiplierForBase:1.118], 1.118, 0.001);
}

- (void)testACapBelowOneIsIgnoredRatherThanShrinkingTheText
{
  // React Native's rule: only a cap of 1 or more counts.
  [self applyProps:^(TestProps &props) {
    props.maxFontSizeMultiplier = 0.5;
  }];

  XCTAssertEqualWithAccuracy([_view effectiveFontSizeMultiplierForBase:1.5], 1.5, 0.001);
}

- (void)testATextSizeChangeDoesNotCancelAnOpenConversion
{
  // The whole point of the library: a system-wide text size change arrives
  // unannounced, and rewriting attributes mid-conversion drops the underline.
  [self beginComposing:@"にほんご"];

  [_view contentSizeCategoryDidChange];

  XCTAssertNotNil([_view input].markedTextRange, @"attributes were written mid-conversion");
  XCTAssertEqualObjects([_view currentText], @"にほんご");
}

- (void)testATextSizeChangeReappliesTheFont
{
  [self applyProps:^(TestProps &props) {
    props.fontSize = 20;
  }];
  UITextView *textView = (UITextView *)[_view input];
  // Stands in for the font left behind by the previous text size. Nothing in
  // the props changes when the system setting does, so a handler that only
  // recomputed without writing would leave this untouched.
  textView.font = [UIFont systemFontOfSize:9];

  [_view contentSizeCategoryDidChange];

  XCTAssertEqual(textView.font.pointSize, 20);
}

#pragma mark - Placeholder

/**
 The label the multiline placeholder is drawn with.

 `UITextView` has no placeholder of its own, so one is overlaid as a sibling of
 the text view. Found by kind rather than exposed through a test hook: the
 label is an implementation detail, but the text it draws is not.
 */
- (UILabel *)placeholderLabel
{
  for (UIView *subview in _view.subviews) {
    if ([subview isKindOfClass:UILabel.class]) {
      return (UILabel *)subview;
    }
  }
  return nil;
}

- (void)testThePlaceholderIsLaidOutOnTheSameLineHeightAsTheText
{
  [self applyProps:^(TestProps &props) {
    props.placeholder = "メッセージを入力";
    props.fontSize = 14;
    props.lineHeight = 20;
  }];

  [_view layoutIfNeeded];

  // The typed text sits on a 20pt line box. A placeholder laid out on the
  // font's own line height instead draws higher, so the text visibly drops the
  // moment the first character is typed.
  XCTAssertEqualWithAccuracy([self placeholderLabel].frame.size.height, 20, 0.5);
}

- (void)testThePlaceholderIsTrackedLikeTheTextThatReplacesIt
{
  [self applyProps:^(TestProps &props) {
    props.placeholder = "Wg";
    props.letterSpacing = 8;
  }];

  UITextView *textView = (UITextView *)[_view input];
  CGFloat textWidth = [@"Wg" sizeWithAttributes:textView.typingAttributes].width;
  CGFloat placeholderWidth = [self placeholderLabel].attributedText.size.width;

  // Untracked, the placeholder is narrower than the text that replaces it, so
  // the first character typed also shifts the line sideways.
  XCTAssertEqualWithAccuracy(placeholderWidth, textWidth, 0.5);
}

#pragma mark - Accessibility

- (void)testAccessibilityLandsOnTheViewThatIsActuallyExposed
{
  // `RCTViewComponentView` writes testID and labels to `accessibilityElement`.
  // If that is the host view rather than the text view, nothing can find the
  // field — not VoiceOver, not Maestro, not XCUITest.
  XCTAssertEqualObjects((id)[_view accessibilityElement], (id)[_view input]);
}

@end

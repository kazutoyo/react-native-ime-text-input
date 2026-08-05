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
- (void)enforceMaxLength;
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
  int textRevision = 0;
  int mostRecentEventCount = 0;
  int maxLength = 0;
  double fontSize = 17;
  double lineHeight = 0;
  double letterSpacing = 0;
  std::string textDecorationLine;
};

@implementation RNImeTextInputTests {
  RNImeTextInput *_view;
  TestProps _values;
  std::shared_ptr<const RNImeTextInputProps> _props;
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

/** Pushes a prop change through the same path the mounting layer uses. */
- (void)applyProps:(void (^)(TestProps &))mutate
{
  mutate(_values);

  auto next = std::make_shared<RNImeTextInputProps>();
  next->multiline = _values.multiline;
  next->text = _values.text;
  next->textRevision = _values.textRevision;
  next->mostRecentEventCount = _values.mostRecentEventCount;
  next->maxLength = _values.maxLength;
  next->fontSize = _values.fontSize;
  next->lineHeight = _values.lineHeight;
  next->letterSpacing = _values.letterSpacing;
  next->textDecorationLine = _values.textDecorationLine;

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

/** Commits it, and runs the callback the delegate would have run. */
- (void)commitComposition
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

  [self commitComposition];

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

  [self commitComposition];

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

  [self commitComposition];

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

#pragma mark - Accessibility

- (void)testAccessibilityLandsOnTheViewThatIsActuallyExposed
{
  // `RCTViewComponentView` writes testID and labels to `accessibilityElement`.
  // If that is the host view rather than the text view, nothing can find the
  // field — not VoiceOver, not Maestro, not XCUITest.
  XCTAssertEqualObjects((id)[_view accessibilityElement], (id)[_view input]);
}

@end

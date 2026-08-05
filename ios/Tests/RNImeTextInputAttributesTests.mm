#import <XCTest/XCTest.h>

#import "RNImeTextInputAttributes.h"

/**
 The attribute dictionary is where the subtlest of the upstream causes lives:
 UIKit silently stops drawing the composition underline when a no-op `NSShadow`
 or a transparent `NSBackgroundColor` is present. Nothing about the app looks
 wrong when that regresses — the underline just goes missing again — so it is
 asserted here rather than left to a human with a Japanese keyboard.
 */
@interface RNImeTextInputAttributesTests : XCTestCase
@end

@implementation RNImeTextInputAttributesTests {
  RNImeTextInputAttributes *_attributes;
}

- (void)setUp
{
  [super setUp];
  _attributes = [RNImeTextInputAttributes new];
}

#pragma mark - The rules that keep the underline visible

- (void)testEmitsNoShadowWhenNoneWasAskedFor
{
  XCTAssertNil([_attributes attributes][NSShadowAttributeName]);
}

- (void)testEmitsNoShadowForAZeroOffsetAndRadiusWithoutAColour
{
  _attributes.shadowOffset = CGSizeZero;
  _attributes.shadowRadius = 0;

  XCTAssertNil([_attributes attributes][NSShadowAttributeName]);
}

- (void)testNeverEmitsABackgroundColour
{
  _attributes.color = UIColor.redColor;
  _attributes.lineHeight = 24;
  _attributes.underline = YES;

  XCTAssertNil([_attributes attributes][NSBackgroundColorAttributeName]);
}

- (void)testEmitsTheShadowThatWasAskedFor
{
  _attributes.shadowColor = UIColor.blackColor;
  _attributes.shadowOffset = CGSizeMake(1, 2);
  _attributes.shadowRadius = 3;

  NSShadow *shadow = [_attributes attributes][NSShadowAttributeName];

  XCTAssertNotNil(shadow);
  XCTAssertEqual(shadow.shadowOffset.width, 1);
  XCTAssertEqual(shadow.shadowOffset.height, 2);
  XCTAssertEqual(shadow.shadowBlurRadius, 3);
}

#pragma mark - Typography

- (void)testResolvesTheFontSizeAndWeight
{
  _attributes.fontSize = 20;
  _attributes.fontWeight = UIFontWeightBold;

  UIFont *font = _attributes.font;

  XCTAssertEqual(font.pointSize, 20);
  UIFontDescriptorSymbolicTraits traits = font.fontDescriptor.symbolicTraits;
  XCTAssertTrue((traits & UIFontDescriptorTraitBold) != 0);
}

- (void)testResolvesItalics
{
  _attributes.italic = YES;

  UIFontDescriptorSymbolicTraits traits = _attributes.font.fontDescriptor.symbolicTraits;

  XCTAssertTrue((traits & UIFontDescriptorTraitItalic) != 0);
}

- (void)testKeepsTheWeightWhenAFamilyIsNamed
{
  // `fontWithName:` alone always returns the regular face, so a named family
  // plus a weight has to be resolved through a descriptor.
  _attributes.fontFamily = @"Avenir";
  _attributes.fontWeight = UIFontWeightHeavy;

  UIFont *font = _attributes.font;

  XCTAssertEqualObjects(font.familyName, @"Avenir");
  XCTAssertNotEqualObjects(font.fontName, [UIFont fontWithName:@"Avenir" size:17].fontName);
}

- (void)testAcceptsAFullFaceNameAsTheFamily
{
  _attributes.fontFamily = @"Avenir-Heavy";

  XCTAssertEqualObjects(_attributes.font.fontName, @"Avenir-Heavy");
}

- (void)testFallsBackToTheSystemFontForAnUnknownFamily
{
  _attributes.fontFamily = @"NoSuchFontFamily";
  _attributes.fontSize = 15;

  XCTAssertEqual(_attributes.font.pointSize, 15);
}

- (void)testTurnsLineHeightIntoAParagraphStyle
{
  _attributes.lineHeight = 26;

  NSParagraphStyle *style = [_attributes attributes][NSParagraphStyleAttributeName];

  XCTAssertEqual(style.minimumLineHeight, 26);
  XCTAssertEqual(style.maximumLineHeight, 26);
}

- (void)testLeavesTheLineHeightAloneWhenUnset
{
  NSParagraphStyle *style = [_attributes attributes][NSParagraphStyleAttributeName];

  XCTAssertTrue(style == nil || style.minimumLineHeight == 0);
}

- (void)testTurnsLetterSpacingIntoKerning
{
  _attributes.letterSpacing = 1.5;

  XCTAssertEqualObjects([_attributes attributes][NSKernAttributeName], @(1.5));
}

- (void)testEmitsNoKerningForZeroLetterSpacing
{
  XCTAssertNil([_attributes attributes][NSKernAttributeName]);
}

- (void)testEmitsUnderlineAndStrikethrough
{
  _attributes.underline = YES;
  _attributes.strikethrough = YES;
  _attributes.decorationStyle = NSUnderlineStyleDouble;

  NSDictionary *attributes = [_attributes attributes];

  XCTAssertEqualObjects(attributes[NSUnderlineStyleAttributeName], @(NSUnderlineStyleDouble));
  XCTAssertEqualObjects(attributes[NSStrikethroughStyleAttributeName], @(NSUnderlineStyleDouble));
}

- (void)testEmitsNoDecorationWhenNoneWasAskedFor
{
  NSDictionary *attributes = [_attributes attributes];

  XCTAssertNil(attributes[NSUnderlineStyleAttributeName]);
  XCTAssertNil(attributes[NSStrikethroughStyleAttributeName]);
}

- (void)testCarriesTheForegroundColour
{
  _attributes.color = UIColor.redColor;

  XCTAssertEqualObjects([_attributes attributes][NSForegroundColorAttributeName], UIColor.redColor);
}

#pragma mark - Equality

- (void)testTwoDefaultInstancesAreEqual
{
  XCTAssertTrue([_attributes isEqualToAttributes:[RNImeTextInputAttributes new]]);
}

- (void)testACopyIsEqualToItsOriginal
{
  _attributes.fontSize = 22;
  _attributes.lineHeight = 30;
  _attributes.color = UIColor.blueColor;

  XCTAssertTrue([_attributes isEqualToAttributes:[_attributes copy]]);
}

- (void)testADifferenceIsNoticed
{
  RNImeTextInputAttributes *other = [_attributes copy];
  other.letterSpacing = 2;

  // Equality decides whether attributes are rewritten at all, and rewriting
  // mid-conversion is what breaks composition — a false "equal" here would be
  // invisible, a false "different" costs an unnecessary write.
  XCTAssertFalse([_attributes isEqualToAttributes:other]);
}

@end

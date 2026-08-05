#import "RNImeTextInputShadowNode.h"

#import <react/renderer/core/LayoutConstraints.h>
#import <react/renderer/core/LayoutContext.h>

namespace facebook::react {

Size RNImeTextInputShadowNodeImpl::measureContent(
    const LayoutContext &layoutContext,
    const LayoutConstraints &layoutConstraints) const
{
  const auto &size = getStateData().contentSize;

  // Zero means the mounted view has not measured itself yet — on the very first
  // layout there is no view. Reporting zero would collapse the field before it
  // ever appears, so the minimum constraint is returned instead and Yoga falls
  // back to whatever the style asks for.
  if (size.height <= 0) {
    return layoutConstraints.minimumSize;
  }

  // Width stays Yoga's business: a text field fills the width it is given, and
  // reporting the text's own width would shrink it to fit its content.
  return layoutConstraints.clamp(Size{
      .width = layoutConstraints.maximumSize.width,
      .height = size.height,
  });
}

} // namespace facebook::react

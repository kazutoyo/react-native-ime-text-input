#pragma once

#include <react/renderer/components/RNImeTextInputSpec/EventEmitters.h>
#include <react/renderer/components/RNImeTextInputSpec/Props.h>
#include <react/renderer/components/RNImeTextInputSpec/ShadowNodes.h>
#include <react/renderer/components/view/ConcreteViewShadowNode.h>

#include "RNImeTextInputState.h"

namespace facebook::react {

/*
 * Custom `ShadowNode` for <RNImeTextInput> that reports the size its text needs.
 *
 * The codegen-generated `RNImeTextInputShadowNode` (in ShadowNodes.h) is a plain
 * `ConcreteViewShadowNode` alias with an empty state and no measure function,
 * so a field would only ever be as tall as its style says. This subclass swaps
 * in `RNImeTextInputState`, sets the `MeasurableYogaNode` trait so Yoga calls
 * `measureContent` during layout, and answers with the size the mounted view
 * last published.
 *
 * That makes the field size itself the way React Native's own `TextInput`
 * does — a multiline field grows with its text, an explicit `height` pins it,
 * and `maxHeight` caps it and lets the `UITextView` scroll inside. No
 * `onContentSizeChange` round trip through JavaScript.
 *
 * The class is named differently from the generated alias to avoid a
 * redefinition clash. It reuses `RNImeTextInputComponentName`, so its component
 * handle and name match the default and the descriptor below can override the
 * generated registration.
 */
class RNImeTextInputShadowNodeImpl final : public ConcreteViewShadowNode<
                                            RNImeTextInputComponentName,
                                            RNImeTextInputProps,
                                            RNImeTextInputEventEmitter,
                                            RNImeTextInputStateData> {
 public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;

  static ShadowNodeTraits BaseTraits()
  {
    auto traits = ConcreteViewShadowNode::BaseTraits();
    // The text has no Yoga children participating in layout.
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    // Registers `measureContent` as the Yoga measure function.
    traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
    return traits;
  }

  Size measureContent(const LayoutContext &layoutContext, const LayoutConstraints &layoutConstraints)
      const override;
};

} // namespace facebook::react

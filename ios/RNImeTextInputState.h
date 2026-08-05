#pragma once

#include <react/renderer/graphics/Float.h>
#include <react/renderer/graphics/Size.h>

#ifdef RN_SERIALIZABLE_STATE
#include <folly/dynamic.h>
#endif

namespace facebook::react {

/*
 * State for <RNImeTextInput>: the size the text currently wants.
 *
 * Named `...StateData` because codegen already defines `RNImeTextInputState` as an
 * alias for the empty `StateData`, and the generated header is included
 * alongside this one.
 *
 * In Fabric, layout runs in C++ on the shadow thread, so a mounted view can
 * never push its size into Yoga directly. What it *can* do is publish it as
 * state, which the shadow node then reports from `measureContent` — that is how
 * this component sizes itself to its text without a round trip through
 * JavaScript.
 *
 * The size has to come from the view rather than being computed in
 * `measureContent`: the text belongs to UIKit, and for an uncontrolled field
 * the shadow tree does not know what it is. That is the difference between an
 * input and a static label, which can measure straight from its props.
 */
class RNImeTextInputStateData final {
 public:
  using Shared = std::shared_ptr<const RNImeTextInputStateData>;

  RNImeTextInputStateData() = default;
  RNImeTextInputStateData(Size contentSize_) : contentSize(contentSize_) {}

#ifdef RN_SERIALIZABLE_STATE
  RNImeTextInputStateData(const RNImeTextInputStateData &previousState, folly::dynamic data)
      : contentSize(Size{
            .width = (Float)data["width"].getDouble(),
            .height = (Float)data["height"].getDouble()}) {}

  folly::dynamic getDynamic() const
  {
    return folly::dynamic::object("width", contentSize.width)("height", contentSize.height);
  }

  MapBuffer getMapBuffer() const
  {
    return MapBufferBuilder::EMPTY();
  }
#endif

  /*
   * Zero until the view has measured itself once. `measureContent` treats that
   * as "nothing to report" and lets Yoga fall back to the style, so a field
   * never collapses to nothing on its first layout.
   */
  const Size contentSize{};
};

} // namespace facebook::react

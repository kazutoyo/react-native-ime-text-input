#pragma once

#import "RNImeTextInputShadowNode.h"

#include <react/renderer/core/ConcreteComponentDescriptor.h>

namespace facebook::react {

/*
 * `ComponentDescriptor` for <RNImeTextInput>, built on the measuring shadow node
 * instead of the codegen-generated one. `RNImeTextInput.mm` registers this through
 * `+componentDescriptorProvider`, which is what gives the component both its
 * measure function and its state type.
 */
using RNImeTextInputComponentDescriptorImpl = ConcreteComponentDescriptor<RNImeTextInputShadowNodeImpl>;

} // namespace facebook::react

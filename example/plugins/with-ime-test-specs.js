const fs = require('node:fs');
const path = require('node:path');

const { withDangerousMod } = require('expo/config-plugins');

/**
 * Makes `pod install` generate the library's unit-test target.
 *
 * CocoaPods only builds a test spec when the pod is declared with
 * `:testspecs`, and autolinking has no way to pass that. Declaring the pod a
 * second time by hand is not an option either — CocoaPods rejects duplicates,
 * and turning autolinking off for it would also stop codegen from seeing the
 * component spec.
 *
 * So the flag is added to the declaration autolinking is about to make, by
 * wrapping the Podfile DSL before it runs. `expo prebuild` rewrites the
 * Podfile, which is why this is a plugin rather than an edit.
 */
const HOOK = `
# Added by plugins/with-ime-test-specs.js
module RNImeTextInputTestSpecs
  def pod(name, *requirements)
    if name == 'RNImeTextInput' && requirements.last.is_a?(Hash)
      requirements.last[:testspecs] = ['Tests']
    end
    super
  end
end
Pod::Podfile.send(:prepend, RNImeTextInputTestSpecs)
`;

module.exports = function withImeTestSpecs(config) {
  return withDangerousMod(config, [
    'ios',
    (modConfig) => {
      const podfile = path.join(modConfig.modRequest.platformProjectRoot, 'Podfile');
      const contents = fs.readFileSync(podfile, 'utf8');

      if (!contents.includes('RNImeTextInputTestSpecs')) {
        fs.writeFileSync(podfile, contents.replace(/^(require .*\n)/m, `$1${HOOK}`));
      }

      return modConfig;
    },
  ]);
};

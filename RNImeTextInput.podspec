require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "RNImeTextInput"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"] || "https://github.com/kazutoyo/react-native-ime-text-input"
  s.license      = package["license"]
  s.authors      = package["author"] || { "react-native-ime-text-input" => "" }

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/kazutoyo/react-native-ime-text-input.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm}"
  s.exclude_files = "ios/Tests/**/*"
  s.private_header_files = "ios/**/*.h"

  # Pulls in React-Core, the codegen'd spec pod, and the Fabric headers.
  install_modules_dependencies(s)

  # Unit tests for the parts that have no JavaScript above them: the attribute
  # dictionary and the marked-text rules. CocoaPods builds this into a
  # `RNImeTextInput-Unit-Tests` scheme in any app that installs the pod from a
  # path — which is why they live here rather than in `example/ios`, a directory
  # `expo prebuild --clean` regenerates.
  s.test_spec "Tests" do |test_spec|
    test_spec.source_files = "ios/Tests/**/*.{h,m,mm}"
  end
end

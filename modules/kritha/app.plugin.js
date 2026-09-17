const { withSettingsGradle, withAppBuildGradle } = require('@expo/config-plugins');

const withDynamicFeatures = (config) => {
  config = withSettingsGradle(config, (config) => {
    if (!config.modResults.contents.includes("include ':feature_litert'")) {
      config.modResults.contents += `
include ':feature_litert'
project(':feature_litert').projectDir = new File(rootProject.projectDir, '../modules/kritha/android/feature_litert')
include ':feature_litertlm'
project(':feature_litertlm').projectDir = new File(rootProject.projectDir, '../modules/kritha/android/feature_litertlm')
include ':feature_onnx'
project(':feature_onnx').projectDir = new File(rootProject.projectDir, '../modules/kritha/android/feature_onnx')
`;
    }
    return config;
  });

  config = withAppBuildGradle(config, (config) => {
    if (!config.modResults.contents.includes("dynamicFeatures =")) {
      config.modResults.contents = config.modResults.contents.replace(
        /android\s*\{/,
        "android {\n    dynamicFeatures = [':feature_litert', ':feature_litertlm', ':feature_onnx']"
      );
    }
    return config;
  });

  return config;
};

module.exports = withDynamicFeatures;

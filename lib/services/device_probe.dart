import 'dart:ffi';
import 'dart:io';

/// Device facts that are available without a platform plugin.
class DeviceStatus {
  const DeviceStatus({
    required this.operatingSystem,
    required this.operatingSystemVersion,
    required this.architecture,
    required this.processorCount,
    required this.locale,
  });

  final String operatingSystem;
  final String operatingSystemVersion;
  final String architecture;
  final int processorCount;
  final String locale;

  static const _supportedSystems = {
    'android',
    'ios',
    'macos',
    'windows',
    'linux',
  };

  bool get isSupported => _supportedSystems.contains(operatingSystem);

  String get platformLabel => switch (operatingSystem) {
    'android' => 'Android',
    'ios' => 'iOS',
    'macos' => 'macOS',
    'windows' => 'Windows',
    'linux' => 'Linux',
    _ => operatingSystem,
  };
}

class DeviceProbe {
  const DeviceProbe();

  DeviceStatus run() {
    return DeviceStatus(
      operatingSystem: Platform.operatingSystem,
      operatingSystemVersion: Platform.operatingSystemVersion,
      architecture: Abi.current().toString(),
      processorCount: Platform.numberOfProcessors,
      locale: Platform.localeName,
    );
  }
}

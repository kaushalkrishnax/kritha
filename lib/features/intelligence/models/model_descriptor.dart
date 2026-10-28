import 'package:freezed_annotation/freezed_annotation.dart';

import 'model_capabilities.dart';

part 'model_descriptor.freezed.dart';

/// Identity and configuration metadata for one model.
///
/// A descriptor never holds a native handle, a loaded engine or download
/// state; those belong to the runtime that consumes it.
@freezed
abstract class ModelDescriptor with _$ModelDescriptor {
  const factory ModelDescriptor({
    required String id,
    required String displayName,
    required String runtimeId,
    required ModelCapabilities capabilities,
    String? modelPath,
  }) = _ModelDescriptor;
}

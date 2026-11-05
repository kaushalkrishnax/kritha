import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/models/active/active_models.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';

void main() {
  group('ActiveModelConfig.withoutModels', () {
    test('removes model from multiModel', () {
      final config = ActiveModelConfig(
        multiModel: MultiModelSelection(
          modelId: 'model-a',
          enabledCapabilities: {ModelCapability.text, ModelCapability.vision},
        ),
        singleModels: const {},
      );
      final pruned = config.withoutModels({'model-a'});
      expect(pruned.multiModel, isNull);
    });

    test('removes model from singleModels', () {
      final config = ActiveModelConfig(
        singleModels: {
          ModelCapability.text: 'model-a',
          ModelCapability.vision: 'model-b',
        },
      );
      final pruned = config.withoutModels({'model-a'});
      expect(pruned.singleModels.containsKey(ModelCapability.text), isFalse);
      expect(pruned.singleModels[ModelCapability.vision], 'model-b');
    });

    test('leaves unrelated assignments intact', () {
      final config = ActiveModelConfig(
        singleModels: {ModelCapability.text: 'model-z'},
      );
      final pruned = config.withoutModels({'model-a', 'model-b'});
      expect(pruned.singleModels[ModelCapability.text], 'model-z');
    });
  });

  group('ActiveModelConfig JSON round-trip', () {
    test('toJson only contains modelId, enabledCapabilities, capability', () {
      final config = ActiveModelConfig(
        multiModel: MultiModelSelection(
          modelId: 'uuid-multi',
          enabledCapabilities: {ModelCapability.text, ModelCapability.vision},
        ),
        singleModels: {ModelCapability.speechRecognition: 'uuid-speech'},
      );
      final json = config.toJson();

      final multi = json['multiModel'] as Map<String, dynamic>;
      expect(multi.keys.toSet(), {'modelId', 'enabledCapabilities'});
      expect(multi['modelId'], 'uuid-multi');

      final singles = (json['singleModels'] as List).cast<Map>();
      expect(singles.first.keys.toSet(), {'capability', 'modelId'});
    });

    test('fromJson -> toJson round-trip is stable', () {
      final original = ActiveModelConfig(
        multiModel: MultiModelSelection(
          modelId: 'uuid-m',
          enabledCapabilities: {ModelCapability.text, ModelCapability.vision},
        ),
        singleModels: {ModelCapability.speechRecognition: 'uuid-s'},
      );
      final json = original.toJson();
      final restored = ActiveModelConfig.fromJson(json);
      expect(restored.multiModel?.modelId, 'uuid-m');
      expect(restored.singleModels[ModelCapability.speechRecognition], 'uuid-s');
    });

    test('multiModel with fewer than 2 enabled capabilities is ignored on load', () {
      final config = ActiveModelConfig.fromJson({
        'multiModel': {
          'modelId': 'uuid-m',
          'enabledCapabilities': ['text'],
        },
        'singleModels': <Map<String, dynamic>>[],
      });
      expect(config.multiModel, isNull);
    });
  });
}

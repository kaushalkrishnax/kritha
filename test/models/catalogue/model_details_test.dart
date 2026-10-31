import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';
import 'package:kritha/features/models/catalogue/hugging_face_urls.dart';
import 'package:kritha/features/models/catalogue/model_identifiers.dart';
import 'package:kritha/features/models/catalogue/model_metadata.dart';

void main() {
  group('metadata classification', () {
    test('groups declared Hub fields by metadata category', () {
      final tags = classifyModelMetadata(
        pipelineTag: 'text-generation',
        libraryName: 'transformers',
        tags: [
          'language:en',
          'language:fr',
          'license:apache-2.0',
          'safetensors',
          'base_model:google/gemma-2b',
        ],
      );

      expect(tags.map((tag) => tag.raw), [
        'text-generation',
        'transformers',
        'language:en',
        'language:fr',
        'license:apache-2.0',
        'safetensors',
        'base_model:google/gemma-2b',
      ]);
      expect(tags.map((tag) => tag.category), [
        ModelMetadataCategory.tasks,
        ModelMetadataCategory.libraries,
        ModelMetadataCategory.languages,
        ModelMetadataCategory.languages,
        ModelMetadataCategory.licenses,
        ModelMetadataCategory.libraries,
        ModelMetadataCategory.other,
      ]);
      expect(tags[0].label, 'text-generation');
      expect(tags[1].label, 'transformers');
      expect(tags[2].label, 'language:en');
      expect(tags[3].label, 'language:fr');
      expect(tags[4].label, 'license:apache-2.0');
      expect(tags[5].label, 'safetensors');
    });

    test('maps bare language codes and library tags from the Hub', () {
      final tags = classifyModelMetadata(
        pipelineTag: 'automatic-speech-recognition',
        libraryName: 'nemo',
        tags: ['pytorch', 'transformers', 'cs', 'en', 'zh', 'region:us'],
      );

      expect(tags.map((tag) => tag.category), [
        ModelMetadataCategory.tasks,
        ModelMetadataCategory.libraries,
        ModelMetadataCategory.libraries,
        ModelMetadataCategory.libraries,
        ModelMetadataCategory.languages,
        ModelMetadataCategory.languages,
        ModelMetadataCategory.languages,
        ModelMetadataCategory.other,
      ]);
      expect(tags.map((tag) => tag.label), [
        'automatic-speech-recognition',
        'nemo',
        'pytorch',
        'transformers',
        'cs',
        'en',
        'zh',
        'region:us',
      ]);
    });

    test('deduplicates identifiers and ignores empty values', () {
      final tags = classifyModelMetadata(
        pipelineTag: 'text-generation',
        libraryName: ' ',
        tags: [
          'text-generation',
          'language:',
          'license:',
          '  ',
          'language:en',
          'language:en',
        ],
      );

      expect(tags, hasLength(2));
      expect(tags.first.raw, 'text-generation');
      expect(tags.last.raw, 'language:en');
    });

    test(
      'compares format and library identifiers ignoring case and separators',
      () {
        expect(modelIdentifiersMatch('LiteRT-LM', 'litert-lm'), isTrue);
        expect(modelIdentifiersMatch('litert_lm', 'litertlm'), isTrue);
        expect(modelIdentifiersMatch('LiteRT LM', 'litert-lm'), isTrue);
        expect(modelIdentifiersMatch('litert-lm', 'transformers'), isFalse);
        expect(
          declaredFormatMatchesLibrary(
            formats: const ['LiteRT-LM'],
            libraryName: 'litert-lm',
          ),
          isTrue,
        );
        expect(
          declaredFormatMatchesLibrary(
            formats: const ['GGUF'],
            libraryName: 'litert-lm',
          ),
          isFalse,
        );
      },
    );

    test('preserves raw tag text and dedupes normalized duplicates', () {
      final tags = classifyModelMetadata(
        pipelineTag: null,
        libraryName: 'LiteRT-LM',
        tags: const ['litert-lm'],
      );

      expect(tags, hasLength(1));
      expect(tags.single.raw, 'LiteRT-LM');
      expect(tags.single.label, 'LiteRT-LM');
      expect(tags.single.normalized, 'litertlm');

      final display = classifyModelMetadata(
        pipelineTag: null,
        libraryName: null,
        tags: const ['litert-lm'],
      );
      expect(display.single.label, 'litert-lm');
    });

    test('returns no tags for an undeclared repository', () {
      final tags = classifyModelMetadata(
        pipelineTag: null,
        libraryName: null,
        tags: const [],
      );

      expect(tags, isEmpty);
    });

    test('defines exactly the five metadata categories', () {
      expect(ModelMetadataCategory.values.map((category) => category.label), [
        'Tasks',
        'Libraries',
        'Languages',
        'Licenses',
        'Other',
      ]);
      for (final category in ModelMetadataCategory.values) {
        if (category == ModelMetadataCategory.other) {
          expect(category.icon, isNull);
        } else {
          expect(category.icon, isNotEmpty);
        }
      }
      expect(
        ModelMetadataCategory.values.map((category) => category.color).toSet(),
        hasLength(ModelMetadataCategory.values.length),
      );
    });
  });

  group('Hugging Face URLs', () {
    test('builds repository addresses from the repository id', () {
      expect(
        HuggingFaceUrls.repository('google/gemma-4-31B-it'),
        'https://huggingface.co/google/gemma-4-31B-it',
      );
    });

    test('builds commit, blob, and tree addresses with encoded segments', () {
      expect(
        HuggingFaceUrls.commit('acme/model', 'abc 123'),
        'https://huggingface.co/acme/model/commit/abc%20123',
      );
      expect(
        HuggingFaceUrls.blob('acme/model', 'main', 'folder/my file.gguf'),
        'https://huggingface.co/acme/model/blob/main/folder/my%20file.gguf',
      );
      expect(
        HuggingFaceUrls.raw('acme/model', 'main', 'README.md'),
        'https://huggingface.co/acme/model/raw/main/README.md',
      );
      expect(
        HuggingFaceUrls.tree('acme/model', 'main', 'folder/nested'),
        'https://huggingface.co/acme/model/tree/main/folder/nested',
      );
    });
  });

  group('repository details', () {
    const model = CatalogueModel(
      id: 'acme/model',
      pipelineTag: 'text-generation',
      libraryName: 'transformers',
      tags: ['safetensors', 'gguf'],
      sha: '1234567890abcdef',
      usedStorage: 4096,
    );

    test('derives canonical links from the branch and commit', () {
      const details = ModelDetails(model: model);

      expect(details.repositoryUrl, 'https://huggingface.co/acme/model');
      expect(
        details.commitUrl,
        'https://huggingface.co/acme/model/commit/1234567890abcdef',
      );
      expect(
        details.fileUrl(const ModelFile(path: 'nested/model.gguf')),
        'https://huggingface.co/acme/model/blob/main/nested/model.gguf',
      );
      expect(
        details.directoryUrl(
          const ModelFile(path: 'nested', type: 'directory'),
        ),
        'https://huggingface.co/acme/model/tree/main/nested',
      );
    });

    test('reports empty README and file collections honestly', () {
      const details = ModelDetails(model: CatalogueModel(id: 'acme/empty'));

      expect(details.readme, isNull);
      expect(details.files, isEmpty);
      expect(details.hasLitertLmFile, isFalse);
      expect(details.repositorySize, 0);
      expect(details.formats, isEmpty);
      expect(details.commitUrl, isNull);
    });

    test('recognizes the LiteRT-LM tag as a format', () {
      const details = ModelDetails(
        model: CatalogueModel(id: 'acme/litert', tags: ['litert-lm']),
      );

      expect(details.formats, ['LiteRT-LM']);
    });

    test('uses declared technical metadata only', () {
      const details = ModelDetails(
        model: model,
        config: {
          'architectures': ['LlamaForCausalLM'],
          'max_position_embeddings': 8192,
        },
        safetensors: {
          'parameters': {'BF16': 7000000000},
        },
      );

      expect(details.architecture, 'LlamaForCausalLM');
      expect(details.contextLength, 8192);
      expect(details.weightPrecisions, ['BF16']);
      expect(details.formats, unorderedEquals(['Safetensors', 'GGUF']));
      expect(details.repositorySize, 4096);
    });
  });

  group('publisher', () {
    test('reads follower statistics and canonicalizes relative avatars', () {
      final publisher = HubPublisher.fromJson(
        {
          'name': 'google',
          'fullname': 'Google',
          'avatarUrl': '/avatars/google.png',
          'numFollowers': 1200,
          'numFollowing': 3,
          'isFollowing': true,
          'isVerified': true,
        },
        fallbackName: 'google',
        organization: true,
      );

      expect(publisher.displayName, 'Google');
      expect(publisher.avatarUrl, 'https://huggingface.co/avatars/google.png');
      expect(publisher.isOrganization, isTrue);
      expect(publisher.followers, 1200);
      expect(publisher.following, 3);
      expect(publisher.isFollowing, isTrue);
      expect(publisher.isVerified, isTrue);
    });

    test('omits unavailable statistics instead of inventing values', () {
      final publisher = HubPublisher.fromJson(
        {'name': 'someone'},
        fallbackName: 'someone',
        organization: false,
      );

      expect(publisher.followers, 0);
      expect(publisher.following, 0);
      expect(publisher.avatarUrl, isNull);
      expect(publisher.isOrganization, isFalse);
    });
  });
}

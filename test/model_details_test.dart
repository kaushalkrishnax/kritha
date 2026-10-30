import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/features/models/catalogue/catalogue_model.dart';
import 'package:kritha/features/models/catalogue/hugging_face_urls.dart';
import 'package:kritha/features/models/catalogue/model_metadata.dart';

void main() {
  group('metadata classification', () {
    test('groups declared Hub fields without a static tag catalogue', () {
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
        ModelMetadataCategory.other,
        ModelMetadataCategory.other,
      ]);
      expect(tags[0].label, 'Text Generation');
      expect(tags[1].label, 'Transformers');
      expect(tags[2].label, 'English');
      expect(tags[3].label, 'French');
      expect(tags[4].label, 'Apache 2.0');
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

    test('returns no tags for an undeclared repository', () {
      final tags = classifyModelMetadata(
        pipelineTag: null,
        libraryName: null,
        tags: const [],
      );

      expect(tags, isEmpty);
      expect(metadataForCategory(tags, null), isEmpty);
    });

    test('filters the combined view by category', () {
      final tags = classifyModelMetadata(
        pipelineTag: 'text-generation',
        libraryName: 'transformers',
        tags: ['language:en', 'license:mit', 'safetensors'],
      );

      expect(metadataForCategory(tags, null), hasLength(5));
      expect(
        metadataForCategory(tags, ModelMetadataCategory.licenses).single.raw,
        'license:mit',
      );
      expect(
        metadataForCategory(tags, ModelMetadataCategory.other).single.raw,
        'safetensors',
      );
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
        expect(category.icon, isNotEmpty);
      }
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

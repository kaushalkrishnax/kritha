import '../../intelligence/models/task_registry.dart';
import 'catalogue_model.dart';

class DerivedTaskMetadata {
  const DerivedTaskMetadata({
    required this.declarations,
    required this.unknownUpstreamValues,
  });

  final List<TaskDeclaration> declarations;
  final List<String> unknownUpstreamValues;
}

DerivedTaskMetadata deriveTaskMetadata(CatalogueModel model) {
  final declarations = <AiTaskId, TaskDeclaration>{};
  final unknown = <String>[];

  void add(String? raw, {required TaskMetadataSource source}) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return;
    final declaration = declarationFromPipelineTag(value, source: source);
    if (declaration == null) {
      if (!unknown.contains(value)) unknown.add(value);
      return;
    }
    final current = declarations[declaration.task];
    if (current == null || declaration.confidence.index < current.confidence.index) {
      declarations[declaration.task] = declaration;
    }
  }

  add(model.pipelineTag, source: TaskMetadataSource.huggingFace);
  for (final tag in model.tags) {
    add(tag, source: TaskMetadataSource.huggingFace);
  }
  return DerivedTaskMetadata(
    declarations: List.unmodifiable(declarations.values),
    unknownUpstreamValues: List.unmodifiable(unknown),
  );
}

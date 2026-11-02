import 'model_capabilities.dart';

enum AiModality { text, image, audio, video }

enum AiFeature { reasoning, toolCalling, structuredOutput, jsonMode, citations }

enum TaskMetadataConfidence { explicit, partial, unknown }

enum TaskMetadataSource { provider, huggingFace, manual }

/// Stable task identifiers used by discovery, persistence, assignment and routing.
enum AiTaskId {
  textGeneration(
    'text_generation',
    'Text generation',
    'Generate text from text input',
    {AiModality.text},
    {AiModality.text},
    true,
  ),
  imageTextToText(
    'image_text_to_text',
    'Image understanding',
    'Understand images with text',
    {AiModality.text, AiModality.image},
    {AiModality.text},
    false,
  ),
  videoTextToText(
    'video_text_to_text',
    'Video understanding',
    'Understand video with text',
    {AiModality.text, AiModality.video},
    {AiModality.text},
    false,
  ),
  audioUnderstanding(
    'audio_understanding',
    'Audio understanding',
    'Understand audio with text',
    {AiModality.text, AiModality.audio},
    {AiModality.text},
    false,
  ),
  automaticSpeechRecognition(
    'automatic_speech_recognition',
    'Speech to text',
    'Transcribe spoken audio',
    {AiModality.audio},
    {AiModality.text},
    false,
  ),
  textToSpeech(
    'text_to_speech',
    'Text to speech',
    'Synthesize speech from text',
    {AiModality.text},
    {AiModality.audio},
    false,
  ),
  audioGeneration(
    'audio_generation',
    'Audio generation',
    'Generate audio',
    {AiModality.text},
    {AiModality.audio},
    false,
  ),
  textToImage(
    'text_to_image',
    'Image generation',
    'Generate images from text',
    {AiModality.text},
    {AiModality.image},
    false,
  ),
  imageEditing(
    'image_editing',
    'Image editing',
    'Edit images from text instructions',
    {AiModality.text, AiModality.image},
    {AiModality.image},
    false,
  ),
  videoGeneration(
    'video_generation',
    'Video generation',
    'Generate video',
    {AiModality.text, AiModality.image},
    {AiModality.video},
    false,
  ),
  embeddings(
    'embeddings',
    'Embeddings',
    'Create vector representations',
    {AiModality.text},
    {AiModality.text},
    false,
  );

  const AiTaskId(
    this.id,
    this.displayName,
    this.description,
    this.inputModalities,
    this.outputModalities,
    this.executable,
  );

  final String id;
  final String displayName;
  final String description;
  final Set<AiModality> inputModalities;
  final Set<AiModality> outputModalities;
  final bool executable;

  static AiTaskId? fromId(String? value) {
    for (final task in values) {
      if (task.id == value) return task;
    }
    return null;
  }
}

class TaskDeclaration {
  const TaskDeclaration({
    required this.task,
    required this.confidence,
    required this.source,
    this.upstreamValue,
    this.refreshedAt,
  });

  final AiTaskId task;
  final TaskMetadataConfidence confidence;
  final TaskMetadataSource source;
  final String? upstreamValue;
  final DateTime? refreshedAt;
}

AiTaskId? taskFromPipelineTag(String? value) {
  final normalized = value?.trim().toLowerCase();
  return switch (normalized) {
    'text-generation' ||
    'text2text-generation' ||
    'text-classification' ||
    'token-classification' ||
    'question-answering' ||
    'summarization' ||
    'translation' ||
    'fill-mask' => AiTaskId.textGeneration,
    'image-text-to-text' ||
    'image-to-text' ||
    'visual-question-answering' ||
    'image-classification' ||
    'object-detection' ||
    'image-segmentation' ||
    'depth-estimation' => AiTaskId.imageTextToText,
    'video-text-to-text' || 'video-classification' => AiTaskId.videoTextToText,
    'automatic-speech-recognition' => AiTaskId.automaticSpeechRecognition,
    'audio-classification' ||
    'voice-activity-detection' => AiTaskId.audioUnderstanding,
    'text-to-speech' => AiTaskId.textToSpeech,
    'text-to-audio' || 'audio-to-audio' => AiTaskId.audioGeneration,
    'text-to-image' || 'unconditional-image-generation' => AiTaskId.textToImage,
    'image-to-image' => AiTaskId.imageEditing,
    'text-to-video' ||
    'image-to-video' ||
    'video-to-video' => AiTaskId.videoGeneration,
    'feature-extraction' || 'sentence-similarity' => AiTaskId.embeddings,
    _ => null,
  };
}

TaskDeclaration? declarationFromPipelineTag(
  String? value, {
  TaskMetadataSource source = TaskMetadataSource.huggingFace,
}) {
  final task = taskFromPipelineTag(value);
  if (task == null) return null;
  return TaskDeclaration(
    task: task,
    confidence: TaskMetadataConfidence.explicit,
    source: source,
    upstreamValue: value,
    refreshedAt: DateTime.now(),
  );
}

AiTaskId? taskForCapability(InferenceCapability capability) =>
    switch (capability) {
      InferenceCapability.textGeneration => AiTaskId.textGeneration,
      InferenceCapability.imageInput => AiTaskId.imageTextToText,
      InferenceCapability.audioInput => AiTaskId.audioUnderstanding,
      InferenceCapability.structuredOutput => null,
    };

Set<InferenceCapability> capabilitiesForTask(AiTaskId task) => switch (task) {
  AiTaskId.textGeneration => {InferenceCapability.textGeneration},
  AiTaskId.imageTextToText => {
    InferenceCapability.textGeneration,
    InferenceCapability.imageInput,
  },
  AiTaskId.audioUnderstanding => {
    InferenceCapability.textGeneration,
    InferenceCapability.audioInput,
  },
  AiTaskId.videoTextToText => const {},
  AiTaskId.automaticSpeechRecognition => {InferenceCapability.audioInput},
  _ => const {},
};

bool qualifiesAsMultimodal(Iterable<AiTaskId> tasks) {
  final values = tasks.toSet();
  if (values.length < 2) return false;
  final modalities = <AiModality>{};
  for (final task in values) {
    modalities
      ..addAll(task.inputModalities)
      ..addAll(task.outputModalities);
  }
  return modalities.any((modality) => modality != AiModality.text);
}

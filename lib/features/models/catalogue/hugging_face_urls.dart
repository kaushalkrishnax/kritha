/// Canonical Hugging Face web addresses built from repository metadata.
abstract final class HuggingFaceUrls {
  static const origin = 'https://huggingface.co';

  static String repository(String repositoryId) =>
      '$origin/${_path(repositoryId)}';

  static String commit(String repositoryId, String sha) =>
      '${repository(repositoryId)}/commit/${Uri.encodeComponent(sha)}';

  static String blob(String repositoryId, String revision, String filePath) =>
      '${repository(repositoryId)}/blob/'
      '${Uri.encodeComponent(revision)}/${_path(filePath)}';

  static String tree(
    String repositoryId,
    String revision, [
    String? directoryPath,
  ]) {
    final root =
        '${repository(repositoryId)}/tree/${Uri.encodeComponent(revision)}';
    final path = directoryPath?.trim();
    return path == null || path.isEmpty ? root : '$root/${_path(path)}';
  }

  static String _path(String value) => value
      .split('/')
      .where((part) => part.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('/');
}

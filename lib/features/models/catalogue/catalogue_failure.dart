/// Why a catalogue request did not produce usable data.
enum CatalogueFailureKind {
  offline,
  rateLimited,
  unauthorized,
  notFound,
  invalidResponse,
  server,
  unknown,
}

/// A user-safe catalogue failure. Transport details stay in this object and
/// never include request headers or credentials.
class CatalogueFailure implements Exception {
  const CatalogueFailure({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  final CatalogueFailureKind kind;
  final String message;
  final int? statusCode;

  bool get canRetry => switch (kind) {
    CatalogueFailureKind.unauthorized => false,
    _ => true,
  };

  String get title => switch (kind) {
    CatalogueFailureKind.offline => 'You appear to be offline',
    CatalogueFailureKind.rateLimited =>
      'Hugging Face is rate-limiting requests',
    CatalogueFailureKind.unauthorized => 'Hugging Face rejected the request',
    CatalogueFailureKind.notFound => 'Repository not found',
    CatalogueFailureKind.invalidResponse =>
      'Unexpected response from Hugging Face',
    CatalogueFailureKind.server => 'Hugging Face is having trouble',
    CatalogueFailureKind.unknown => 'The catalogue could not be loaded',
  };

  @override
  String toString() => 'CatalogueFailure($kind, $message, $statusCode)';
}

/// Internal signal that a newer request superseded this one.
class CatalogueCancelled implements Exception {
  const CatalogueCancelled();
}

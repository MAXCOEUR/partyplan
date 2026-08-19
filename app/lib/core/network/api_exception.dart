/// Erreur renvoyée par l'API, au format RFC 9457 (§8.1).
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.title,
    this.detail,
    this.code,
    this.correlationId,
  });

  final int statusCode;
  final String title;
  final String? detail;

  /// Code métier stable, par exemple `event.not_found`.
  final String? code;

  /// Identifiant de corrélation renvoyé par l'API (NF-OPS-02). C'est ce que
  /// l'utilisateur peut communiquer au support.
  final String? correlationId;

  /// Une ressource inexistante et une ressource hors périmètre partagent le même
  /// statut : l'interface ne doit donc jamais laisser entendre que « l'accès est
  /// refusé », ce qui révélerait l'existence de la ressource (RG-SEC-02).
  bool get estIntrouvable => statusCode == 404;

  bool get estNonAuthentifie => statusCode == 401;

  bool get estConflit => statusCode == 409;

  bool get estTropDeRequetes => statusCode == 429;

  factory ApiException.depuisProblemDetails(
    int statusCode,
    Map<String, dynamic> corps,
  ) => ApiException(
    statusCode: statusCode,
    title: corps['title'] as String? ?? 'Une erreur est survenue.',
    detail: corps['detail'] as String?,
    code: corps['code'] as String?,
    correlationId: corps['correlationId'] as String?,
  );

  @override
  String toString() => 'ApiException($statusCode, $title)';
}

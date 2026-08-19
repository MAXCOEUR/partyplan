/// Configuration injectée à la compilation.
///
/// Flutter Web produit des fichiers statiques : une valeur lue à l'exécution
/// n'existerait pas. D'où `--dart-define`, également utilisé par le Dockerfile.
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5080',
  );

  static const apiPrefix = '/v1';

  static Uri get apiRoot => Uri.parse('$apiBaseUrl$apiPrefix');

  /// Vrai lorsque l'application pointe une API locale. Sert uniquement à afficher un
  /// repère visuel de développement, jamais à modifier un comportement métier.
  static bool get estLocal =>
      apiBaseUrl.contains('localhost') || apiBaseUrl.contains('127.0.0.1');
}

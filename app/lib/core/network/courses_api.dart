import '../models/article_course.dart';
import 'api_client.dart';
import 'cle_idempotence.dart';

/// Appels d'API de la liste de courses (§8.2).
///
/// Écrit à la main, comme les autres clients : le générateur produit un paquet séparé
/// et une chaîne de compilation supplémentaire, disproportionnés pour sept endpoints.
///
/// La mise en file hors ligne est déclarée opération par opération. Elle ne peut pas
/// être un comportement par défaut : s'attribuer un article se rejoue sans dommage,
/// tandis qu'un ajout rejoué créerait un doublon si sa clé d'idempotence avait changé
/// entre-temps.
class CoursesApi {
  const CoursesApi(this._client);

  final ApiClient _client;

  String _base(String evenementId) => '/events/$evenementId/shopping';

  Future<ListeCourses> lister(String evenementId) => _client.get(
    _base(evenementId),
    analyser: (corps) =>
        ListeCourses.depuisJson(corps! as Map<String, dynamic>),
  );

  /// Ajoute un article (`EF-CRS-01`).
  ///
  /// La clé d'idempotence est engendrée ici et non fournie par l'appelant : un double
  /// appui sur « Ajouter » part deux fois avec deux clés, ce que le serveur traite
  /// comme deux ajouts — c'est le comportement attendu, l'utilisateur ayant demandé
  /// deux fois. La clé protège du rejeu réseau, pas de la double intention.
  Future<ArticleCourse> ajouter(
    String evenementId, {
    required String nom,
    required CategorieCourse categorie,
    double? quantite,
    String? unite,
    double? prixEstime,
    String? note,
  }) => _client.post(
    _base(evenementId),
    corps: {
      'name': nom,
      'category': categorie.versApi,
      'quantity': ?quantite,
      if (unite != null && unite.isNotEmpty) 'unit': unite,
      'estimatedPrice': ?prixEstime,
      if (note != null && note.isNotEmpty) 'note': note,
    },
    cleIdempotence: nouvelleCleIdempotence(),
    analyser: (corps) =>
        ArticleCourse.depuisJson(corps! as Map<String, dynamic>),
  );

  /// Modifie un article (`EF-CRS-08`).
  ///
  /// Sans clé d'idempotence : une modification rejouée aboutit au même état.
  Future<ArticleCourse> modifier(
    String evenementId,
    String articleId, {
    required String nom,
    required CategorieCourse categorie,
    double? quantite,
    String? unite,
    double? prixEstime,
    String? note,
  }) => _client.patch(
    '${_base(evenementId)}/$articleId',
    corps: {
      'name': nom,
      'category': categorie.versApi,
      'quantity': ?quantite,
      if (unite != null && unite.isNotEmpty) 'unit': unite,
      'estimatedPrice': ?prixEstime,
      if (note != null && note.isNotEmpty) 'note': note,
    },
    analyser: (corps) =>
        ArticleCourse.depuisJson(corps! as Map<String, dynamic>),
  );

  /// Supprime un article. Refusé par le serveur si une dépense y est rattachée.
  Future<void> supprimer(String evenementId, String articleId) =>
      _client.delete('${_base(evenementId)}/$articleId');

  /// S'attribue un article (`EF-CRS-03`).
  ///
  /// Différable hors ligne : l'attribution est idempotente par nature, se l'attribuer
  /// deux fois revient à se l'attribuer une fois. C'est aussi le geste le plus probable
  /// dans un magasin, là où le réseau manque.
  Future<ArticleCourse> attribuer(String evenementId, String articleId) =>
      _client.post(
        '${_base(evenementId)}/$articleId/claim',
        differable: true,
        analyser: (corps) =>
            ArticleCourse.depuisJson(corps! as Map<String, dynamic>),
      );

  /// Retire son attribution (`EF-CRS-04`).
  Future<ArticleCourse> liberer(String evenementId, String articleId) =>
      _client.deleteWithResult(
        '${_base(evenementId)}/$articleId/claim',
        differable: true,
        analyser: (corps) =>
            ArticleCourse.depuisJson(corps! as Map<String, dynamic>),
      );

  /// Déclare l'achat (`EF-CRS-05`, `EF-CRS-06`).
  ///
  /// [prixPaye] laissé nul marque l'article acheté sans engendrer de dépense : marquer
  /// acheté et déclarer une dépense sont deux gestes distincts, et envoyer un prix nul
  /// créerait une dépense à zéro euro dans les comptes de l'événement.
  Future<ArticleCourse> acheter(
    String evenementId,
    String articleId, {
    double? quantiteObtenue,
    double? prixPaye,
  }) => _client.post(
    '${_base(evenementId)}/$articleId/purchase',
    corps: {
      'purchasedQuantity': ?quantiteObtenue,
      'actualPrice': ?prixPaye,
    },
    cleIdempotence: nouvelleCleIdempotence(),
    analyser: (corps) =>
        ArticleCourse.depuisJson(corps! as Map<String, dynamic>),
  );
}

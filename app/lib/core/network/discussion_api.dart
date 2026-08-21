import 'package:dio/dio.dart';

import '../models/message.dart';
import 'api_client.dart';

/// Appels d'API de la discussion d'un événement (§8.2).
///
/// Un seul fil par événement : pas de salons, conformément à la décision produit du
/// 21/08/2026. Les « salons » sont les dossiers d'épingles.
class DiscussionApi {
  const DiscussionApi(this._client);

  final ApiClient _client;

  String _fil(String evenementId) => '/events/$evenementId/messages';

  String _epingles(String evenementId) => '/events/$evenementId/pins';

  Future<FilDiscussion> lire(String evenementId) => _client.get(
    _fil(evenementId),
    // Jamais mis en cache : un fil de discussion servi depuis le disque après une
    // coupure afficherait une conversation vieille de plusieurs heures comme si elle
    // était à jour.
    cacheable: false,
    analyser: (corps) =>
        FilDiscussion.depuisJson(corps! as Map<String, dynamic>),
  );

  /// Envoie un message : texte, image, réponse, mentions.
  ///
  /// Sans clé d'idempotence, à la différence d'une dépense : un message envoyé deux
  /// fois se voit et se supprime, tandis qu'une dépense en double fausse
  /// silencieusement les soldes.
  Future<Message> envoyer(
    String evenementId, {
    String? corps,
    String? urlPieceJointe,
    String? repondreA,
    String? sondageId,
    List<String> mentions = const [],
  }) => _client.post(
    _fil(evenementId),
    corps: {
      'body': ?corps,
      'attachmentUrl': ?urlPieceJointe,
      'replyToMessageId': ?repondreA,
      'pollId': ?sondageId,
      if (mentions.isNotEmpty) 'mentionedMemberIds': mentions,
    },
    analyser: (reponse) => Message.depuisJson(reponse! as Map<String, dynamic>),
  );

  Future<Message> modifier(
    String evenementId,
    String messageId, {
    required String corps,
  }) => _client.patch(
    '${_fil(evenementId)}/$messageId',
    corps: {'body': corps},
    analyser: (reponse) => Message.depuisJson(reponse! as Map<String, dynamic>),
  );

  Future<void> supprimer(String evenementId, String messageId) =>
      _client.delete('${_fil(evenementId)}/$messageId');

  /// Pose ou retire une réaction. Interrupteur : le même emoji renvoyé la retire.
  Future<Message> basculerReaction(
    String evenementId,
    String messageId,
    String emoji,
  ) => _client.put(
    '${_fil(evenementId)}/$messageId/reactions',
    corps: {'emoji': emoji},
    analyser: (reponse) => Message.depuisJson(reponse! as Map<String, dynamic>),
  );

  /// Dépose une image et renvoie son adresse, à joindre ensuite à un message.
  ///
  /// Deux temps plutôt qu'un : l'envoi est long sur un réseau de soirée, et le séparer
  /// permet de montrer une progression puis de laisser écrire une légende sans retenir
  /// l'image.
  ///
  /// Le fichier part tel quel : c'est le serveur qui réduit et réencode. La compression
  /// s'applique alors quel que soit l'appareil, et le réencodage supprime les
  /// métadonnées EXIF — dont la géolocalisation qu'un téléphone inscrit dans chaque
  /// photo, et qui serait sinon publiée à tout l'événement.
  Future<String> deposerImage(
    String evenementId, {
    required List<int> octets,
    required String nomFichier,
    required String typeMime,
  }) {
    final donnees = FormData.fromMap({
      // Le type est déclaré explicitement : sans lui, Dio annonce
      // « application/octet-stream », que le serveur refuse.
      'file': MultipartFile.fromBytes(
        octets,
        filename: nomFichier,
        contentType: DioMediaType.parse(typeMime),
      ),
    });

    return _client.post<String>(
      '${_fil(evenementId)}/images',
      corps: donnees,
      analyser: (corps) => (corps! as Map<String, dynamic>)['url'] as String,
    );
  }

  // ---------------------------------------------------------------- épingles ----

  Future<PageEpingles> lireEpingles(
    String evenementId, {
    String? dossierId,
  }) => _client.get(
    _epingles(evenementId),
    parametres: dossierId == null ? null : {'folderId': dossierId},
    cacheable: false,
    analyser: (corps) =>
        PageEpingles.depuisJson(corps! as Map<String, dynamic>),
  );

  /// Épingle un message. [dossierId] nul le laisse sans rangement.
  Future<Epingle> epingler(
    String evenementId,
    String messageId, {
    String? dossierId,
  }) => _client.post(
    '${_fil(evenementId)}/$messageId/pin',
    corps: {'folderId': dossierId},
    analyser: (corps) => Epingle.depuisJson(corps! as Map<String, dynamic>),
  );

  Future<void> desepingler(String evenementId, String messageId) =>
      _client.delete('${_fil(evenementId)}/$messageId/pin');

  Future<DossierEpingles> creerDossier(String evenementId, String nom) =>
      _client.post(
        '${_epingles(evenementId)}/folders',
        corps: {'name': nom},
        analyser: (corps) =>
            DossierEpingles.depuisJson(corps! as Map<String, dynamic>),
      );

  Future<void> supprimerDossier(String evenementId, String dossierId) =>
      _client.delete('${_epingles(evenementId)}/folders/$dossierId');
}

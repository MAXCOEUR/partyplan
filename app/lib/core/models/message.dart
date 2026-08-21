/// Réaction à un message : un emoji, combien l'ont posé, et si j'en fais partie.
class Reaction {
  const Reaction({
    required this.emoji,
    required this.nombre,
    required this.laMienne,
  });

  factory Reaction.depuisJson(Map<String, dynamic> json) => Reaction(
    emoji: json['emoji'] as String? ?? '',
    nombre: json['count'] as int? ?? 0,
    laMienne: json['mine'] as bool? ?? false,
  );

  final String emoji;
  final int nombre;

  /// Vrai lorsque l'appelant a posé cette réaction. Appuyer de nouveau la retire.
  final bool laMienne;
}

/// Personne citée dans un message.
class Mention {
  const Mention({required this.membreId, required this.nom});

  factory Mention.depuisJson(Map<String, dynamic> json) => Mention(
    membreId: json['memberId'] as String,
    nom: json['displayName'] as String? ?? '',
  );

  final String membreId;
  final String nom;
}

/// Message cité par une réponse, réduit à ce qu'il faut pour s'y retrouver.
class Citation {
  const Citation({required this.id, required this.auteur, required this.corps});

  factory Citation.depuisJson(Map<String, dynamic> json) => Citation(
    id: json['id'] as String,
    auteur: json['authorDisplayName'] as String? ?? '',
    corps: json['body'] as String?,
  );

  final String id;
  final String auteur;

  /// Nul lorsque le message cité a été supprimé depuis.
  final String? corps;
}

/// Message de la discussion d'un événement.
class Message {
  const Message({
    required this.id,
    required this.auteurMembreId,
    required this.auteur,
    required this.corps,
    required this.urlPieceJointe,
    required this.sondageId,
    required this.citation,
    required this.reactions,
    required this.mentions,
    required this.leMien,
    required this.modifie,
    required this.supprime,
    required this.epingle,
    required this.envoyeLe,
  });

  factory Message.depuisJson(Map<String, dynamic> json) => Message(
    id: json['id'] as String,
    auteurMembreId: json['authorMemberId'] as String? ?? '',
    auteur: json['authorDisplayName'] as String? ?? '',
    corps: json['body'] as String?,
    urlPieceJointe: json['attachmentUrl'] as String?,
    sondageId: json['pollId'] as String?,
    citation: json['replyTo'] == null
        ? null
        : Citation.depuisJson(json['replyTo'] as Map<String, dynamic>),
    reactions: [
      for (final r in json['reactions'] as List<dynamic>? ?? const [])
        Reaction.depuisJson(r as Map<String, dynamic>),
    ],
    mentions: [
      for (final m in json['mentions'] as List<dynamic>? ?? const [])
        Mention.depuisJson(m as Map<String, dynamic>),
    ],
    leMien: json['mine'] as bool? ?? false,
    modifie: json['edited'] as bool? ?? false,
    supprime: json['deleted'] as bool? ?? false,
    epingle: json['pinned'] as bool? ?? false,
    envoyeLe: DateTime.parse(json['createdAt'] as String),
  );

  final String id;
  final String auteurMembreId;
  final String auteur;

  /// Nul si le message ne portait qu'une image, ou s'il a été supprimé.
  final String? corps;

  final String? urlPieceJointe;

  /// Sondage porté par ce message, le cas échéant.
  final String? sondageId;

  final Citation? citation;
  final List<Reaction> reactions;
  final List<Mention> mentions;
  final bool leMien;

  /// La modification reste visible : un message réécrit en silence permettrait de
  /// faire dire à quelqu'un le contraire de ce qu'il a écrit.
  final bool modifie;

  /// Message supprimé. Sa place subsiste, sans son contenu, pour que les réponses qui
  /// le citent restent compréhensibles.
  final bool supprime;

  final bool epingle;
  final DateTime envoyeLe;

  bool get porteUneImage =>
      urlPieceJointe != null && urlPieceJointe!.isNotEmpty;
}

/// Fil de discussion, du plus ancien au plus récent.
class FilDiscussion {
  const FilDiscussion({
    required this.messages,
    this.encorePlusHaut = false,
    this.nonLus = 0,
    this.premierNonLuId,
  });

  factory FilDiscussion.depuisJson(Map<String, dynamic> json) => FilDiscussion(
    messages: [
      for (final m in json['items'] as List<dynamic>? ?? const [])
        Message.depuisJson(m as Map<String, dynamic>),
    ],
    encorePlusHaut: json['hasMore'] as bool? ?? false,
    nonLus: json['unreadCount'] as int? ?? 0,
    premierNonLuId: json['firstUnreadId'] as String?,
  );

  final List<Message> messages;

  /// Vrai s'il reste des messages plus anciens à demander en remontant.
  final bool encorePlusHaut;

  /// Nombre de messages non lus, y compris ceux qui ne sont pas dans cette page.
  final int nonLus;

  /// Premier message non lu. Peut se trouver au-dessus des messages chargés.
  final String? premierNonLuId;

  bool get estVide => messages.isEmpty;

  /// Le plus ancien message connu : le point de départ de la page suivante.
  String? get plusAncienId => messages.isEmpty ? null : messages.first.id;

  FilDiscussion avec({List<Message>? messages, bool? encorePlusHaut}) =>
      FilDiscussion(
        messages: messages ?? this.messages,
        encorePlusHaut: encorePlusHaut ?? this.encorePlusHaut,
        nonLus: nonLus,
        premierNonLuId: premierNonLuId,
      );
}

/// Dossier de rangement des messages épinglés. Toujours partagé.
class DossierEpingles {
  const DossierEpingles({
    required this.id,
    required this.nom,
    required this.nombre,
  });

  factory DossierEpingles.depuisJson(Map<String, dynamic> json) =>
      DossierEpingles(
        id: json['id'] as String,
        nom: json['name'] as String? ?? '',
        nombre: json['count'] as int? ?? 0,
      );

  final String id;
  final String nom;
  final int nombre;
}

/// Message épinglé, avec son rangement.
class Epingle {
  const Epingle({
    required this.id,
    required this.dossierId,
    required this.dossierNom,
    required this.message,
    required this.epingleLe,
  });

  factory Epingle.depuisJson(Map<String, dynamic> json) => Epingle(
    id: json['id'] as String,
    dossierId: json['folderId'] as String?,
    dossierNom: json['folderName'] as String?,
    message: Message.depuisJson(json['message'] as Map<String, dynamic>),
    epingleLe: DateTime.parse(json['createdAt'] as String),
  );

  final String id;

  /// Nul pour une épingle sans rangement : classer est facultatif.
  final String? dossierId;
  final String? dossierNom;

  final Message message;
  final DateTime epingleLe;
}

/// Épingles et dossiers d'un événement.
class PageEpingles {
  const PageEpingles({required this.dossiers, required this.epingles});

  factory PageEpingles.depuisJson(Map<String, dynamic> json) => PageEpingles(
    dossiers: [
      for (final d in json['folders'] as List<dynamic>? ?? const [])
        DossierEpingles.depuisJson(d as Map<String, dynamic>),
    ],
    epingles: [
      for (final e in json['items'] as List<dynamic>? ?? const [])
        Epingle.depuisJson(e as Map<String, dynamic>),
    ],
  );

  final List<DossierEpingles> dossiers;
  final List<Epingle> epingles;

  bool get estVide => epingles.isEmpty;
}

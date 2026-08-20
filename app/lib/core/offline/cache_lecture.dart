import 'dart:convert';

import '../storage/magasin_local.dart';

/// Entrée de cache : la charge utile telle qu'elle a été reçue, et la date de réception.
///
/// La date n'est pas un détail de journalisation : c'est elle que l'écran affiche
/// (« données du 20/08 à 14 h 32 »). Sans elle, l'utilisateur ne distingue pas un état
/// ancien d'un état courant, et décide sur des chiffres périmés.
class EntreeCache {
  const EntreeCache({required this.charge, required this.recuA});

  final Object? charge;
  final DateTime recuA;
}

/// Dernière réponse connue de chaque lecture.
class CacheLecture {
  const CacheLecture(this._magasin);

  static const prefixe = 'pp_cache|';

  final MagasinLocal _magasin;

  /// Clé stable d'une lecture.
  ///
  /// Les paramètres sont triés : deux requêtes équivalentes dont les paramètres ont été
  /// construits dans un ordre différent doivent partager une seule entrée.
  String cle(String chemin, Map<String, dynamic>? parametres) {
    if (parametres == null || parametres.isEmpty) {
      return '${prefixe}GET|$chemin';
    }

    final tries = parametres.keys.toList()..sort();
    final rendu = tries.map((c) => '$c=${parametres[c]}').join('&');

    return '${prefixe}GET|$chemin?$rendu';
  }

  Future<void> enregistrer(
    String chemin,
    Map<String, dynamic>? parametres,
    Object? charge,
    DateTime recuA,
  ) => _magasin.ecrire(
    cle(chemin, parametres),
    jsonEncode({'recuA': recuA.toIso8601String(), 'charge': charge}),
  );

  Future<EntreeCache?> lire(
    String chemin,
    Map<String, dynamic>? parametres,
  ) async {
    final brut = await _magasin.lire(cle(chemin, parametres));

    if (brut == null) {
      return null;
    }

    final decode = jsonDecode(brut) as Map<String, dynamic>;

    return EntreeCache(
      charge: decode['charge'],
      recuA: DateTime.parse(decode['recuA'] as String),
    );
  }

  /// Vidé à la déconnexion et au changement de compte : le cache contient le contenu
  /// d'événements privés, et le laisser en place sur un appareil partagé démentirait la
  /// promesse d'événement privé.
  Future<void> purger() => _magasin.supprimerPrefixe(prefixe);
}

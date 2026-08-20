import 'dart:convert';
import 'dart:math';

import '../storage/magasin_local.dart';

/// Écriture inscrite en file, en attente de départ.
class EcritureEnAttente {
  const EcritureEnAttente({
    required this.id,
    required this.methode,
    required this.chemin,
    required this.corps,
    required this.cleIdempotence,
    required this.inscriteA,
    required this.tentatives,
  });

  final String id;
  final String methode;
  final String chemin;
  final Object? corps;

  /// Fixée à l'inscription, jamais régénérée. Voir [FileEcritures.inscrire].
  final String cleIdempotence;

  final DateTime inscriteA;
  final int tentatives;

  EcritureEnAttente avecTentatives(int valeur) => EcritureEnAttente(
    id: id,
    methode: methode,
    chemin: chemin,
    corps: corps,
    cleIdempotence: cleIdempotence,
    inscriteA: inscriteA,
    tentatives: valeur,
  );

  Map<String, dynamic> versJson() => {
    'id': id,
    'methode': methode,
    'chemin': chemin,
    'corps': corps,
    'cleIdempotence': cleIdempotence,
    'inscriteA': inscriteA.toIso8601String(),
    'tentatives': tentatives,
  };

  static EcritureEnAttente depuisJson(Map<String, dynamic> json) =>
      EcritureEnAttente(
        id: json['id'] as String,
        methode: json['methode'] as String,
        chemin: json['chemin'] as String,
        corps: json['corps'],
        cleIdempotence: json['cleIdempotence'] as String,
        inscriteA: DateTime.parse(json['inscriteA'] as String),
        tentatives: json['tentatives'] as int,
      );
}

/// Écritures qui n'ont pas pu partir, rejouées dans l'ordre à la reconnexion.
class FileEcritures {
  FileEcritures(this._magasin);

  static const cleFile = 'pp_file|ecritures';

  final MagasinLocal _magasin;
  final Random _alea = Random.secure();

  /// Inscrit une écriture et lui attribue **définitivement** sa clé d'idempotence.
  ///
  /// C'est le point qui fait tenir tout le mécanisme. Régénérer la clé au rejeu
  /// produirait une clé neuve, l'idempotence du serveur ne reconnaîtrait rien, et le
  /// rejeu créerait un doublon — exactement ce que la file est censée empêcher.
  Future<EcritureEnAttente> inscrire({
    required String methode,
    required String chemin,
    Object? corps,
  }) async {
    final ecriture = EcritureEnAttente(
      id: _identifiant(),
      methode: methode,
      chemin: chemin,
      corps: corps,
      cleIdempotence: _identifiant(),
      inscriteA: DateTime.now(),
      tentatives: 0,
    );

    final attente = await enAttente();
    attente.add(ecriture);
    await _ecrire(attente);

    return ecriture;
  }

  /// Écritures en attente, dans l'ordre d'inscription.
  ///
  /// L'ordre est significatif : rejouer en parallèle ferait par exemple partir un
  /// changement de statut avant l'adhésion qui le rend possible.
  Future<List<EcritureEnAttente>> enAttente() async {
    final brut = await _magasin.lire(cleFile);

    if (brut == null) {
      return [];
    }

    return (jsonDecode(brut) as List)
        .map((e) => EcritureEnAttente.depuisJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> retirer(String id) async {
    final attente = await enAttente();
    attente.removeWhere((e) => e.id == id);
    await _ecrire(attente);
  }

  Future<void> incrementerTentatives(String id) async {
    final attente = await enAttente();

    await _ecrire([
      for (final e in attente)
        if (e.id == id) e.avecTentatives(e.tentatives + 1) else e,
    ]);
  }

  Future<void> purger() => _magasin.supprimer(cleFile);

  Future<void> _ecrire(List<EcritureEnAttente> ecritures) => _magasin.ecrire(
    cleFile,
    jsonEncode([for (final e in ecritures) e.versJson()]),
  );

  /// 128 bits en hexadécimal. `Random.secure` et non `Random` : une clé d'idempotence
  /// devinable permettrait à un tiers de faire rejouer la réponse d'autrui.
  String _identifiant() => List.generate(
    16,
    (_) => _alea.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

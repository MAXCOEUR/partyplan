import 'package:shared_preferences/shared_preferences.dart';

/// Magasin clé-valeur persistant, hors secrets.
///
/// Distinct de [SessionStore], qui protège les jetons : ce qui transite ici est du
/// contenu applicatif, pas un secret d'authentification. Les mélanger reviendrait à
/// faire passer des kilo-octets de JSON par le trousseau de la plateforme.
///
/// Interface plutôt qu'implémentation directe : `shared_preferences` convient aux
/// charges actuelles — une liste d'événements, une liste de membres — mais pas au fil
/// d'activité paginé du lot 1.10. Le jour venu, seul ce fichier change.
abstract interface class MagasinLocal {
  Future<String?> lire(String cle);

  Future<void> ecrire(String cle, String valeur);

  Future<void> supprimer(String cle);

  Future<Set<String>> cles();

  Future<void> supprimerPrefixe(String prefixe);
}

/// Implémentation sur `shared_preferences`.
class MagasinPreferences implements MagasinLocal {
  MagasinPreferences();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<String?> lire(String cle) async => (await _instance).getString(cle);

  @override
  Future<void> ecrire(String cle, String valeur) async =>
      (await _instance).setString(cle, valeur);

  @override
  Future<void> supprimer(String cle) async {
    await (await _instance).remove(cle);
  }

  @override
  Future<Set<String>> cles() async => (await _instance).getKeys();

  @override
  Future<void> supprimerPrefixe(String prefixe) async {
    final prefs = await _instance;

    // La liste est copiée avant l'itération : supprimer pendant que l'on parcourt
    // l'ensemble renvoyé par getKeys lèverait une ConcurrentModificationError.
    for (final cle in prefs.getKeys().toList()) {
      if (cle.startsWith(prefixe)) {
        await prefs.remove(cle);
      }
    }
  }
}

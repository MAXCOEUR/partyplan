import 'dart:convert';

/// Rôle plateforme porté par le jeton d'accès.
///
/// Le rôle est lu dans le jeton plutôt que demandé au serveur : interroger le profil au
/// démarrage ajouterait un appel réseau à chaque lancement, et ferait apparaître
/// l'entrée du back-office une seconde après le reste de l'écran.
///
/// La signature n'est pas vérifiée — elle ne peut pas l'être sans la clé publique du
/// serveur, et elle n'a pas à l'être : cette valeur ne sert qu'à afficher ou masquer une
/// entrée de menu. Un jeton forgé afficherait l'entrée, et l'API refuserait chacun de
/// ses appels (`RG-ADM-05`). Aucun droit ne se décide ici.
String rolePlateformeDuJeton(String? jetonAcces) {
  const ordinaire = 'User';

  if (jetonAcces == null || jetonAcces.isEmpty) {
    return ordinaire;
  }

  final segments = jetonAcces.split('.');

  if (segments.length != 3) {
    return ordinaire;
  }

  try {
    final charge = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
    );

    if (charge is! Map<String, Object?>) {
      return ordinaire;
    }

    final role = charge['pp:platform_role'];

    return role is String && role.isNotEmpty ? role : ordinaire;
  } on FormatException {
    // Jeton tronqué par un stockage local abîmé : au pire l'entrée manque, jamais
    // l'application ne doit refuser de démarrer pour cela.
    return ordinaire;
  }
}

/// Vrai pour `Support` et `PlatformAdmin`.
bool estPersonnelPlateforme(String role) => role != 'User';

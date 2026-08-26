/// Calculs de dates de l'application.
library;

/// Nombre de jours calendaires entre aujourd'hui et [cible].
///
/// Calculé en jours de calendrier et non en tranches de vingt-quatre heures : une
/// soirée du lendemain soir doit s'annoncer « demain », même s'il ne reste que huit
/// heures. Compter en heures dirait « aujourd'hui », ce que personne ne comprendrait.
///
/// [depuis] n'existe que pour les tests : une fonction qui lit l'horloge sans pouvoir
/// être fixée rend ses appelants intestables.
int joursCalendairesJusqua(DateTime cible, {DateTime? depuis}) {
  final maintenant = depuis ?? DateTime.now();

  return DateTime.utc(cible.year, cible.month, cible.day)
      .difference(
        DateTime.utc(maintenant.year, maintenant.month, maintenant.day),
      )
      .inDays;
}

/// Ancienneté lisible d'un instant passé : « à l'instant », « il y a 5 min »,
/// « il y a 2 h », « hier », puis la date.
///
/// Les paliers sont choisis pour ce que la personne veut savoir : dans l'heure, la
/// minute compte ; dans la journée, l'heure suffit ; au-delà, seule la date importe.
/// Écrire « il y a 1 437 minutes » serait exact et inutilisable.
///
/// [depuis] n'existe que pour les tests : une fonction qui lit l'horloge sans pouvoir
/// être fixée rend ses appelants intestables.
String ilYA(DateTime instant, {DateTime? depuis}) {
  final maintenant = depuis ?? DateTime.now();
  final ecart = maintenant.difference(instant);

  if (ecart.inMinutes < 1) {
    return 'à l’instant';
  }

  if (ecart.inMinutes < 60) {
    return 'il y a ${ecart.inMinutes} min';
  }

  if (ecart.inHours < 24) {
    return 'il y a ${ecart.inHours} h';
  }

  final jours = -joursCalendairesJusqua(instant, depuis: maintenant);

  if (jours == 1) {
    return 'hier';
  }

  if (jours < 7) {
    return 'il y a $jours jours';
  }

  return '${instant.day.toString().padLeft(2, '0')}/'
      '${instant.month.toString().padLeft(2, '0')}/${instant.year}';
}

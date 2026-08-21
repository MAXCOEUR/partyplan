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

  return DateTime(cible.year, cible.month, cible.day)
      .difference(DateTime(maintenant.year, maintenant.month, maintenant.day))
      .inDays;
}

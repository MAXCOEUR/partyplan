import 'api_exception.dart';

/// Délai avant une nouvelle tentative, ou `null` pour renoncer.
///
/// Riverpod 3 réessaie de lui-même tout provider en échec, avec un délai qui double.
/// Appliqué sans distinction, ce comportement s'acharne sur des réponses qui ne
/// changeront jamais : un refus d'autorisation renvoie six fois le même refus, et
/// l'écran reste sur son indicateur de chargement pendant toute la série — le
/// « chargement infini » qu'on observe alors n'est pas une requête qui traîne, c'est une
/// succession de refus.
///
/// Ne sont retentées que les erreurs dont l'issue peut changer d'elle-même : une coupure
/// réseau, un serveur momentanément indisponible.
Duration? repriseApres(int tentative, Object erreur) {
  const tentativesMaximales = 3;

  if (tentative >= tentativesMaximales) {
    return null;
  }

  if (erreur is ApiException && !_peutChangerDAvis(erreur.statusCode)) {
    return null;
  }

  // 400 ms, puis 800 ms. Assez pour traverser un redéploiement, assez court pour que
  // l'écran ne paraisse pas figé.
  return Duration(milliseconds: 400 * (1 << (tentative - 1)));
}

/// Vrai lorsqu'une nouvelle tentative peut donner un autre résultat.
///
/// Un code d'erreur du client (400 à 499) désigne la requête elle-même : elle sera
/// refusée à l'identique tant qu'elle n'aura pas changé. Le 408 et le 429 font
/// exception — l'un est un délai dépassé, l'autre une limite de débit, et tous deux
/// passent en réessayant plus tard.
bool _peutChangerDAvis(int statut) {
  if (statut == 408 || statut == 429) {
    return true;
  }

  return statut < 400 || statut >= 500;
}

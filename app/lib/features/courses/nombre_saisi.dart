/// Conversions entre un nombre et sa saisie à l'écran.
///
/// Regroupées ici parce que trois formulaires en dépendent — article, achat, dépense —
/// et qu'une copie qui oublierait la virgule refuserait « 30,50 » sur un clavier
/// français.
library;

/// Analyse un nombre saisi. Rend `null` sur un champ vide ou illisible.
///
/// La virgule décimale est acceptée : c'est ce que produit un clavier français, et
/// `double.tryParse` ne la reconnaît pas.
double? nombreDepuisTexte(String? texte) {
  if (texte == null) {
    return null;
  }

  final propre = texte.trim().replaceAll(' ', '').replaceAll(',', '.');

  return propre.isEmpty ? null : double.tryParse(propre);
}

/// Rend un nombre pour l'affichage dans un champ : « 24 » et non « 24.0 ».
String nombreVersTexte(double valeur) => valeur == valeur.roundToDouble()
    ? valeur.toStringAsFixed(0)
    : valeur.toString().replaceAll('.', ',');

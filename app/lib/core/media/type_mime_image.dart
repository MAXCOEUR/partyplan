/// Déduit le type MIME d'une image depuis son nom ou son chemin.
///
/// Le serveur valide le type déclaré avant de tenter le décodage (RG-USR-01) : envoyer
/// `application/octet-stream`, ce que fait Dio par défaut, se ferait refuser. Le type
/// est donc déduit ici, et un format non reconnu est refusé localement plutôt que
/// téléversé pour rien.
///
/// La déduction porte sur le nom, pas sur le contenu : c'est une commodité, pas un
/// contrôle de sécurité. Le contrôle réel reste le décodage effectif côté serveur.
String? typeMimeImage(String nomOuChemin) {
  // Le recadreur ne rend qu'un chemin : on isole le dernier segment, quel que soit le
  // séparateur, avant de chercher l'extension.
  final nom = nomOuChemin.split(RegExp(r'[/\\]')).last;
  final separateur = nom.lastIndexOf('.');

  // `separateur <= 0` couvre à la fois l'absence d'extension et les noms qui commencent
  // par un point, comme « .jpg », qui sont des fichiers cachés sans extension.
  if (separateur <= 0) {
    return null;
  }

  return switch (nom.substring(separateur + 1).toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    _ => null,
  };
}

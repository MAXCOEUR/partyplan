/// Chaînes de l'interface.
///
/// Regroupées ici afin qu'aucune chaîne ne soit codée en dur dans un écran
/// (NF-I18N-01). Le passage à des fichiers ARB traduits se fera sans toucher aux
/// écrans, seul ce fichier changeant de nature.
///
/// Règles de rédaction appliquées : phrase capitalisée, verbe actif, un libellé
/// d'action garde le même mot du bouton au message de confirmation.
abstract final class PpStrings {
  static const nomProduit = 'PartyPlan';
  static const signature = 'Organise. Partage. Profite !';

  // --- Navigation (RG-UI-01 : cinq entrées, pas une de plus) ---
  static const ongletAccueil = 'Accueil';
  static const ongletCourses = 'Courses';
  static const ongletDepenses = 'Dépenses';
  static const ongletPlanning = 'Planning';
  static const ongletPlus = 'Plus';

  // --- Accueil ---
  static const evenementsAVenir = 'À venir';
  static const evenementsPasses = 'Passés';
  static const creerUnEvenement = 'Créer un événement';
  static const rejoindreUnEvenement = 'Rejoindre avec un code';

  static const accueilVideTitre = 'Aucun événement pour le moment';
  static const accueilVideExplication =
      'Crée ta première soirée, puis partage le lien. '
      'Tes invités répondent sans avoir à créer de compte.';

  // --- Courses ---
  static const aPrendre = 'À prendre';
  static const jeMenOccupe = 'Je m’en occupe';
  static const coursesAvancement = 'Courses';

  // --- Dépenses et remboursements ---
  static const totalDepense = 'Dépensé';
  static const tuDois = 'Tu dois';
  static const onTeDoit = 'On te doit';
  static const marquerRembourse = 'Marquer comme remboursé';

  // --- Présences ---
  static String presents(int presents, int invites) =>
      '$presents / $invites présents';

  // --- Erreurs ---
  static const erreurReseau =
      'Impossible de joindre PartyPlan. Vérifie ta connexion, puis réessaie.';
  static const erreurIntrouvable =
      'Cet événement n’existe pas, ou tu n’en fais plus partie.';
  static const erreurArticleDejaPris =
      'Quelqu’un vient de s’en occuper. La liste a été mise à jour.';
  static const erreurTropDeTentatives =
      'Trop de tentatives. Patiente une minute avant de réessayer.';
  static const erreurEnregistrement =
      'Ta modification n’a pas été enregistrée. Elle a été annulée.';
  static const reessayer = 'Réessayer';

  // --- Développement ---
  static const bandeauDeveloppement = 'API locale';
}

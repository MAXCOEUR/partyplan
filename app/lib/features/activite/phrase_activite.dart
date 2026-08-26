import '../../core/models/activite.dart';
import '../../design/components/pp_money.dart';
import '../../l10n/generated/pp_localisations.dart';

/// Compose la phrase affichée d'une ligne du fil.
///
/// La phrase n'est jamais stockée : la ligne est inaltérable en base (`RG-FIL-02`), une
/// formulation maladroite y resterait pour toujours, et le fil ne serait jamais
/// traduisible (`NF-I18N-01`).
///
/// La phrase ne porte pas le nom de l'auteur : il est affiché séparément, en gras, par
/// la ligne elle-même. La mettre ici obligerait chaque appelant à la découper pour
/// styler ce nom.
///
/// **Aucune catégorie ne fait défaut.** Une ligne écrite par une version future du
/// serveur dégrade vers une phrase générique — le fil est en ajout seul, il n'y aura
/// pas de correction rétroactive, et l'écran doit la traverser.
String phraseActivite(PpL10n l10n, Activite activite) {
  String libelle() => activite.texte('libelle') ?? '';
  String montant(String cle) {
    final valeur = activite.montant(cle);
    return valeur == null ? '' : PpMoney.enTexte(valeur);
  }

  return switch (activite.categorie) {
    'member.joined' => l10n.filArriveMembre,

    'member.status_changed' => l10n.filChangeStatut(
      _reponse(l10n, activite.texte('vers')),
    ),

    'item.created' => l10n.filAjouteArticle(libelle()),
    'item.deleted' => l10n.filSupprimeArticle(libelle()),
    'item.claimed' => l10n.filPrendArticle(libelle()),
    'item.unclaimed' => l10n.filLibereArticle(libelle()),

    // Sans prix déclaré, la phrase courte : « pour 0,00 € » annoncerait un prix.
    'item.purchased' => activite.montant('montant') == null
        ? l10n.filAcheteArticle(libelle())
        : l10n.filAcheteArticleMontant(libelle(), montant('montant')),

    'expense.created' => l10n.filCreeDepense(libelle(), montant('montant')),
    'expense.updated' => l10n.filModifieDepense(
      libelle(),
      montant('ancienMontant'),
      montant('montant'),
    ),
    'expense.deleted' => l10n.filSupprimeDepense(libelle(), montant('montant')),

    'settlement.marked' => l10n.filMarqueReglement(
      activite.texte('de') ?? '',
      activite.texte('vers') ?? '',
      montant('montant'),
    ),
    'settlement.cancelled' => l10n.filAnnuleReglement(
      activite.texte('de') ?? '',
      activite.texte('vers') ?? '',
      montant('montant'),
    ),

    'event.date_or_place_changed' => _dateOuLieu(l10n, activite.liste('champs')),

    _ => l10n.filActionInconnue,
  };
}

/// Traduit un statut de présence tel qu'il est stocké.
///
/// Les valeurs viennent de la base et sont figées : les traduire ici plutôt que de les
/// afficher brutes évite qu'un fil français annonce « a répondu Going ».
String _reponse(PpL10n l10n, String? statut) => switch (statut) {
  'Going' => l10n.presenceOui,
  'NotGoing' => l10n.presenceNon,
  'Maybe' => l10n.presencePeutEtre,
  'Late' => l10n.presenceEnRetard,
  'Leaving' || 'LeavingEarly' => l10n.presencePartTot,
  _ => l10n.presenceSansReponse,
};

String _dateOuLieu(PpL10n l10n, List<String> champs) {
  final date = champs.contains('date');
  final lieu = champs.contains('lieu');

  if (date && lieu) {
    return l10n.filChangeDateEtLieu;
  }

  // Le lieu seul est le cas rare ; la date reste le repli, y compris pour une ligne
  // ancienne écrite avant que le payload n'existe.
  return lieu ? l10n.filChangeLieu : l10n.filChangeDate;
}

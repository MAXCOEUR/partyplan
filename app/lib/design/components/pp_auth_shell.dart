import 'package:flutter/material.dart';

import '../../l10n/marque.dart';
import '../tokens.dart';
import 'pp_card.dart';

/// Enveloppe des écrans de compte : connexion, inscription, mot de passe.
///
/// Les quatre écrans dupliquaient la même structure — un `Center`, un
/// `SingleChildScrollView`, une largeur bornée à 420 — et le résultat flottait : sur un
/// écran de bureau, une petite colonne de champs posée au milieu d'un vaste fond gris,
/// sans rien qui la retienne. La colonne n'était même pas centrée, la contrainte de
/// largeur se posant avant le centrage.
///
/// Le formulaire vit désormais dans une carte, sur les deux tailles d'écran. C'est ce
/// qui lui donne une assise : une carte a un bord, une ombre et une couleur propre, là
/// où des champs posés à même le fond n'ont aucun rang.
///
/// La signature de la marque apparaît sous la carte. Elle figure dans la charte et
/// n'était utilisée nulle part.
class PpAuthShell extends StatelessWidget {
  const PpAuthShell({
    required this.cleFormulaire,
    required this.enfants,
    this.barre,
    this.autofill = true,
    super.key,
  });

  /// Clé du formulaire de l'écran.
  final GlobalKey<FormState> cleFormulaire;

  /// Contenu de la carte, empilé verticalement et étiré en largeur.
  final List<Widget> enfants;

  /// Barre supérieure, quand l'écran est atteint depuis un autre.
  final PreferredSizeWidget? barre;

  /// Groupe de remplissage automatique. Utile là où le navigateur ou le gestionnaire de
  /// mots de passe a quelque chose à proposer, inutile sur une demande de réinitialisation.
  final bool autofill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colonne = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: enfants,
    );

    final carte = PpCard(
      padding: const EdgeInsets.all(PpSpacing.xl),
      child: Form(
        key: cleFormulaire,
        child: autofill ? AutofillGroup(child: colonne) : colonne,
      ),
    );

    return Scaffold(
      appBar: barre,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: PpSpacing.lg,
              vertical: PpSpacing.xl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    carte,
                    const SizedBox(height: PpSpacing.xl),
                    Text(
                      PpMarque.signature,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

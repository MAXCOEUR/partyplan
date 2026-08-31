import 'package:flutter/material.dart';

import 'pp_logo_google.dart';

/// Le bouton « Continuer avec Google », à la forme officielle de Google.
///
/// C'est le seul composant de l'application qui ne suit pas la charte : sa couleur, son
/// contour, sa typographie et son libellé sont ceux de Google, sur toutes les
/// plateformes. C'est voulu. Un bouton de connexion tierce se reconnaît avant d'être lu,
/// et le redessiner aux couleurs de PartyPlan le rendrait méconnaissable — en plus de
/// contrevenir aux directives de la marque.
///
/// Il reproduit ce que le SDK Google rend déjà de lui-même sur le Web, où sa forme est
/// imposée et ne se retouche pas. C'est donc Android qui rejoint le Web, et non
/// l'inverse.
class PpBoutonGoogle extends StatelessWidget {
  const PpBoutonGoogle({required this.onPressed, super.key});

  /// Nulle pour un bouton désactivé, pendant qu'une connexion est déjà en cours.
  final VoidCallback? onPressed;

  /// Hauteur officielle. Elle est aussi la hauteur minimale d'une zone tactile
  /// confortable, ce qui tombe bien.
  static const _hauteur = 40.0;

  /// Marges officielles : 12 avant le logo, 10 entre le logo et le texte.
  static const _margeLaterale = 12.0;
  static const _ecart = 10.0;

  // Couleurs de la marque, thème clair puis thème sombre. Elles ne se dérivent pas du
  // ColorScheme de l'application : ce sont des constantes de Google.
  static const _fondClair = Color(0xFFFFFFFF);
  static const _contourClair = Color(0xFF747775);
  static const _texteClair = Color(0xFF1F1F1F);
  static const _fondSombre = Color(0xFF131314);
  static const _contourSombre = Color(0xFF8E918F);
  static const _texteSombre = Color(0xFFE3E3E3);

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final fond = sombre ? _fondSombre : _fondClair;
    final contour = sombre ? _contourSombre : _contourClair;
    final texte = sombre ? _texteSombre : _texteClair;
    final desactive = onPressed == null;

    return Semantics(
      button: true,
      child: Opacity(
        // Un bouton désactivé s'estompe plutôt que de changer de couleur : la palette
        // est celle de Google, et n'a pas de variante d'état.
        opacity: desactive ? 0.5 : 1,
        child: SizedBox(
          height: _hauteur,
          child: Material(
            color: fond,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_hauteur / 2),
              side: BorderSide(color: contour),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('connexion-google'),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _margeLaterale),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const PpLogoGoogle(),
                    const SizedBox(width: _ecart),
                    Flexible(
                      child: Text(
                        'Continuer avec Google',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          // Roboto est la typographie de la marque. Absente — sur le
                          // Web, sur un poste de bureau — la police par défaut prend le
                          // relais plutôt que le Poppins de l'application, qui rendrait
                          // le bouton étranger à ce que Google fait afficher ailleurs.
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.25,
                          color: texte,
                        ),
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

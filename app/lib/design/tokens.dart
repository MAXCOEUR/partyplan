import 'package:flutter/material.dart';

/// Jetons de design de PartyPlan.
///
/// Source unique des couleurs, espacements, rayons et durées. La palette provient
/// de `docs/brand/charte.md` : ce fichier l'applique, il ne la redéfinit pas.
abstract final class PpColors {
  // --- Palette de la charte ---
  static const violet = Color(0xFF6C5CE7);
  static const violetClair = Color(0xFFA855F7);
  static const rose = Color(0xFFFF4D8D);
  static const vert = Color(0xFF00C896);
  static const orange = Color(0xFFFFB020);
  static const rouge = Color(0xFFEF4444);
  static const bleu = Color(0xFF3B82F6);

  // --- Neutres clairs ---
  static const fondClair = Color(0xFFF8FAFC);
  static const surfaceClaire = Color(0xFFFFFFFF);

  /// Bordure du thème clair. La charte ne donne que la bordure sombre (#334155) :
  /// utilisée telle quelle sur fond clair, elle serait beaucoup trop dure.
  static const bordureClaire = Color(0xFFE2E8F0);
  static const texteClair = Color(0xFF0F172A);
  static const texteSecondaireClair = Color(0xFF64748B);

  // --- Neutres sombres ---
  static const fondSombre = Color(0xFF0F172A);
  static const surfaceSombre = Color(0xFF1E293B);
  static const bordureSombre = Color(0xFF334155);
  static const texteSombre = Color(0xFFF8FAFC);
  static const texteSecondaireSombre = Color(0xFF94A3B8);

  // --- Variantes accessibles ---
  //
  // Les couleurs de la charte sont vives : posées comme texte sur un fond clair, elles
  // tombent sous le seuil WCAG AA de 4,5:1 (vert 2,07:1, orange 1,75:1, rose 3,00:1,
  // rouge 3,60:1). Ces variantes assombries conservent la teinte et franchissent le
  // seuil. La couleur de charte reste utilisée telle quelle sur fond sombre, où elle
  // passe, et pour les aplats portant du texte blanc.
  //
  // Ne jamais utiliser directement une couleur vive comme couleur de texte sur fond
  // clair : passer par [texteSur].
  static const vertTexte = Color(0xFF008262);
  static const roseTexte = Color(0xFFC93D6F);
  static const orangeTexte = Color(0xFF996A13);
  static const rougeTexte = Color(0xFFD23C3C);

  /// Aplat rose supportant du texte blanc à 4,58:1. Le rose de charte n'atteint que
  /// 3,14:1 avec du blanc, insuffisant pour un libellé de 14 px.
  static const roseAplat = Color(0xFFCF3E72);

  /// Renvoie la déclinaison lisible d'une couleur d'accent selon le thème.
  ///
  /// Sur fond sombre, les couleurs de charte franchissent déjà le seuil : les
  /// assombrir les rendrait au contraire illisibles.
  static Color texteSur(Color accent, Brightness brightness) {
    if (brightness == Brightness.dark) {
      return accent;
    }

    return switch (accent.toARGB32()) {
      0xFF00C896 => vertTexte,
      0xFFFF4D8D => roseTexte,
      0xFFFFB020 => orangeTexte,
      0xFFEF4444 => rougeTexte,
      _ => accent,
    };
  }

  /// Dégradé de marque, réservé aux surfaces d'accueil et au bouton principal.
  /// Utilisé partout, il perdrait tout effet.
  static const degradeMarque = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, violetClair],
  );
}

/// Échelle d'espacement. Multiples de 4 : aucune valeur intermédiaire improvisée.
abstract final class PpSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

abstract final class PpRadius {
  static const sm = 8.0;
  static const md = 12.0;

  /// Rayon des cartes. Généreux, conformément au registre convivial du §10.3.
  static const card = 20.0;
  static const pill = 999.0;
}

abstract final class PpDuration {
  static const rapide = Duration(milliseconds: 120);
  static const normale = Duration(milliseconds: 220);
  static const lente = Duration(milliseconds: 400);
}

abstract final class PpElevation {
  /// Ombre unique du produit. Une seule, très douce : les élévations multiples de
  /// Material donnent une impression d'application de gestion.
  static List<BoxShadow> carte(bool sombre) => [
    BoxShadow(
      color: sombre
          ? Colors.black.withValues(alpha: 0.35)
          : PpColors.texteClair.withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}

/// Seuils de mise en page.
///
/// PartyPlan est d'abord une application de téléphone, mais elle est aussi servie sur
/// navigateur : sans ces seuils, la même interface s'étire sur toute la largeur d'un
/// écran de bureau, le libellé d'un article se retrouvant à un mètre de son bouton.
abstract final class PpBreakpoints {
  /// Au-delà, la navigation passe sur le côté et le contenu se pose dans un rail.
  /// En dessous, une navigation latérale mangerait la moitié de l'écran.
  static const large = 840.0;

  /// Largeur maximale d'une colonne de contenu. Choisie pour qu'une carte reste
  /// lisible d'un seul regard : au-delà, l'œil doit balayer.
  static const railContenu = 600.0;
}

/// Cible tactile minimale exigée par NF-A11Y-02.
abstract final class PpA11y {
  static const cibleMinimale = 44.0;
}

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Champ de formulaire du produit.
class PpField extends StatelessWidget {
  const PpField({
    required this.label,
    this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.aide,
    this.lignes = 1,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final bool enabled;

  /// Nombre de lignes visibles. Au-delà de une, le champ devient multiligne et son
  /// action clavier passe au retour à la ligne.
  final int lignes;

  /// Texte d'aide sous le champ. Sert à énoncer une règle avant l'erreur, plutôt
  /// qu'à la place.
  final String? aide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: PpSpacing.xs),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          enabled: enabled,
          maxLines: obscure ? 1 : lignes,
          decoration: InputDecoration(hintText: hint),
        ),
        if (aide != null)
          Padding(
            padding: const EdgeInsets.only(top: PpSpacing.xs),
            child: Text(aide!, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}

/// Bouton principal, avec état de chargement intégré.
///
/// L'indicateur remplace le libellé au lieu de s'y ajouter : la largeur du bouton ne
/// bouge pas, et l'appui reste impossible pendant l'envoi.
class PpPrimaryButton extends StatelessWidget {
  const PpPrimaryButton({
    required this.label,
    required this.onPressed,
    this.enCours = false,
    this.icone,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enCours;
  final IconData? icone;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: enCours ? null : onPressed,
      child: enCours
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icone != null) ...[
                  Icon(icone, size: 18),
                  const SizedBox(width: PpSpacing.sm),
                ],
                Text(label),
              ],
            ),
    ),
  );
}

/// Bandeau d'erreur d'un formulaire.
///
/// Dit ce qui s'est passé, sans excuse ni formulation vague : l'utilisateur a une
/// action à corriger.
class PpFormError extends StatelessWidget {
  const PpFormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couleur = PpColors.texteSur(PpColors.rouge, theme.brightness);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PpSpacing.md),
      decoration: BoxDecoration(
        color: PpColors.rouge.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(PpRadius.md),
        border: Border.all(color: couleur.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: couleur),
          const SizedBox(width: PpSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: couleur),
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête d'un écran d'authentification : logo, titre, sous-titre.
class PpAuthHeader extends StatelessWidget {
  const PpAuthHeader({required this.titre, required this.sousTitre, super.key});

  final String titre;
  final String sousTitre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: PpColors.degradeMarque,
            borderRadius: BorderRadius.circular(PpRadius.card),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.celebration_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(height: PpSpacing.lg),
        Text(titre, style: theme.textTheme.displayMedium),
        const SizedBox(height: PpSpacing.xs),
        Text(
          sousTitre,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

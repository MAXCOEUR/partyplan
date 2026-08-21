import 'package:flutter/material.dart';

import '../tokens.dart';

/// Famille d'emoji, telle qu'elle est présentée dans le sélecteur.
class FamilleEmoji {
  const FamilleEmoji(this.nom, this.emojis);

  final String nom;
  final List<String> emojis;
}

/// Emoji proposés pour réagir à un message.
///
/// Une sélection, non un catalogue. Un clavier complet de plusieurs milliers d'emoji
/// transforme un geste d'une seconde en fouille, et l'immense majorité n'a rien à faire
/// dans une conversation de soirée. Les familles suivent ce dont on se sert
/// réellement : approuver, rire, la fête, ce qu'on boit et ce qu'on mange.
///
/// « Fréquents » vient en tête et reprend les réactions les plus employées : elles
/// doivent rester à portée immédiate, sans défilement.
const famillesEmoji = <FamilleEmoji>[
  FamilleEmoji('Fréquents', ['👍', '🎉', '😂', '❤️', '😮', '🙏', '🔥', '👀']),
  FamilleEmoji('Visages', [
    '😀',
    '😅',
    '🥳',
    '😍',
    '🤩',
    '😎',
    '🤔',
    '😐',
    '😴',
    '🤒',
    '😭',
    '😱',
    '🤯',
    '🙄',
    '😬',
    '🤗',
  ]),
  FamilleEmoji('Gestes', [
    '👎',
    '👏',
    '🙌',
    '🤝',
    '✌️',
    '🤞',
    '💪',
    '🫡',
    '✅',
    '❌',
    '❓',
    '❗',
  ]),
  FamilleEmoji('Fête', [
    '🥂',
    '🍾',
    '🎂',
    '🎈',
    '🎁',
    '🎊',
    '🕺',
    '💃',
    '🎵',
    '🎤',
    '🪩',
    '🎮',
    '🃏',
    '🎯',
  ]),
  FamilleEmoji('À boire et à manger', [
    '🍺',
    '🍷',
    '🍹',
    '☕',
    '🧊',
    '🥤',
    '🍕',
    '🍔',
    '🌮',
    '🥗',
    '🍟',
    '🧀',
    '🥖',
    '🍫',
    '🍿',
    '🍩',
  ]),
  FamilleEmoji('Pratique', [
    '🚗',
    '🚕',
    '🚲',
    '🏠',
    '🔑',
    '💰',
    '🧾',
    '🛒',
    '🧹',
    '🌡️',
    '☀️',
    '🌧️',
    '⏰',
    '📍',
  ]),
];

/// Choix d'un emoji pour réagir à un message.
///
/// Renvoie l'emoji choisi, ou `null` si la feuille est refermée sans choix.
class PpSelecteurEmoji extends StatelessWidget {
  const PpSelecteurEmoji({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PpSpacing.lg,
          vertical: PpSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Réagir', style: theme.textTheme.titleMedium),
            const SizedBox(height: PpSpacing.sm),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final famille in famillesEmoji) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        top: PpSpacing.md,
                        bottom: PpSpacing.xs,
                      ),
                      child: Text(
                        famille.nom,
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.1,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: PpSpacing.xs,
                      runSpacing: PpSpacing.xs,
                      children: [
                        for (final emoji in famille.emojis)
                          _Pastille(emoji: emoji),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(PpRadius.md),
    onTap: () => Navigator.of(context).pop(emoji),
    child: SizedBox(
      // Cible tactile pleine (NF-A11Y-02) : un emoji de 22 points laissé nu se rate
      // une fois sur trois avec le pouce.
      width: PpA11y.cibleMinimale,
      height: PpA11y.cibleMinimale,
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
    ),
  );
}

/// Ouvre le choix d'un emoji. Renvoie `null` si la feuille est refermée sans choix.
Future<String?> ouvrirSelecteurEmoji(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const PpSelecteurEmoji(),
    );

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/network/evenements_api.dart';
import '../../design/components/pp_form.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';

/// Saisie d'un code court `PLAN-XXXXXX` (EF-INV-03).
///
/// La saisie est tolérante — minuscules, espaces, tirets, absence de préfixe — parce
/// qu'un code recopié depuis une conversation arrive rarement propre.
class RejoindrePage extends ConsumerStatefulWidget {
  const RejoindrePage({super.key});

  @override
  ConsumerState<RejoindrePage> createState() => _RejoindrePageState();
}

class _RejoindrePageState extends ConsumerState<RejoindrePage> {
  final _code = TextEditingController();

  String? _erreur;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.codeCourtTitre)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PpSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: PpSpacing.xl),
              PpField(
                label: l10n.codeCourtChamp,
                controller: _code,
                hint: 'PLAN-XXXXXX',
                aide: l10n.codeCourtAide,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _continuer(l10n),
              ),
              if (_erreur != null) PpFormError(_erreur!),
              const SizedBox(height: PpSpacing.lg),
              PpPrimaryButton(
                label: l10n.codeCourtContinuer,
                onPressed: () => _continuer(l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _continuer(PpL10n l10n) {
    final normalise = EvenementsApi.normaliserCode(_code.text);

    if (normalise.isEmpty) {
      setState(() => _erreur = l10n.codeCourtRequis);
      return;
    }

    setState(() => _erreur = null);
    context.push(PpRoutes.versApercuParCode(normalise));
  }
}

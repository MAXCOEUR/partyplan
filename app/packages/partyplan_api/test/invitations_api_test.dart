import 'package:test/test.dart';
import 'package:partyplan_api/partyplan_api.dart';


/// tests for InvitationsApi
void main() {
  final instance = PartyplanApi().getInvitationsApi();

  group(InvitationsApi, () {
    // Rejoint depuis un code court. En-tête Idempotency-Key obligatoire.
    //
    //Future<JoinResult> joinByShortCode(String shortCode, JoinBody joinBody) async
    test('test joinByShortCode', () async {
      // TODO
    });

    // Rejoint l'événement. Aucun compte n'est exigé. En-tête Idempotency-Key obligatoire.
    //
    //Future<JoinResult> joinEvent(String token, JoinBody joinBody) async
    test('test joinEvent', () async {
      // TODO
    });

    // Résolution d'un code court PLAN-XXXXXX.
    //
    //Future<JoinPreview> previewByShortCode(String shortCode) async
    test('test previewByShortCode', () async {
      // TODO
    });

    // Aperçu restreint : nom, date, lieu, nombre de participants.
    //
    //Future<JoinPreview> previewInvitation(String token) async
    test('test previewInvitation', () async {
      // TODO
    });

  });
}

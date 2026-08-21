import 'package:test/test.dart';
import 'package:partyplan_api/partyplan_api.dart';


/// tests for SettlementsApi
void main() {
  final instance = PartyplanApi().getSettlementsApi();

  group(SettlementsApi, () {
    // Annule un marquage. La ligne subsiste, horodatée comme annulée.
    //
    //Future<SettlementsPage> cancelSettlement(String eventId, String settlementId) async
    test('test cancelSettlement', () async {
      // TODO
    });

    // Soldes, règlements proposés et règlements effectués.
    //
    //Future<SettlementsPage> getSettlements(String eventId) async
    test('test getSettlements', () async {
      // TODO
    });

    // Marque un remboursement comme effectué. En-tête Idempotency-Key obligatoire.
    //
    //Future<SettlementsPage> markSettlement(String eventId, MarkSettlementBody markSettlementBody) async
    test('test markSettlement', () async {
      // TODO
    });

  });
}

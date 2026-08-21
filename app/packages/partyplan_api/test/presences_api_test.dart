import 'package:test/test.dart';
import 'package:partyplan_api/partyplan_api.dart';


/// tests for PresencesApi
void main() {
  final instance = PartyplanApi().getPresencesApi();

  group(PresencesApi, () {
    // Quitte l'événement. Le propriétaire doit d'abord transférer.
    //
    //Future leaveEvent(String eventId) async
    test('test leaveEvent', () async {
      // TODO
    });

    // Participants, avec statut et horaires.
    //
    //Future<BuiltList<MemberView>> listMembers(String eventId) async
    test('test listMembers', () async {
      // TODO
    });

    // Exclut un participant. Ses données financières subsistent.
    //
    //Future removeMember(String eventId, String memberId) async
    test('test removeMember', () async {
      // TODO
    });

    // Déclare sa présence. Chacun ne modifie que la sienne.
    //
    //Future<MemberView> setMyAttendance(String eventId, AttendanceBody attendanceBody) async
    test('test setMyAttendance', () async {
      // TODO
    });

    // Transfère la propriété. L'ancien propriétaire devient administrateur. En-tête Idempotency-Key obligatoire.
    //
    //Future transferOwnership(String eventId, String memberId) async
    test('test transferOwnership', () async {
      // TODO
    });

  });
}

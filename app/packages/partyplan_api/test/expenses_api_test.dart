import 'package:test/test.dart';
import 'package:partyplan_api/partyplan_api.dart';


/// tests for ExpensesApi
void main() {
  final instance = PartyplanApi().getExpensesApi();

  group(ExpensesApi, () {
    // Crée une dépense. En-tête Idempotency-Key obligatoire.
    //
    //Future<ExpenseDetail> createExpense(String eventId, ExpenseBody expenseBody) async
    test('test createExpense', () async {
      // TODO
    });

    // Supprime une dépense. La trace subsiste, les soldes sont recalculés.
    //
    //Future deleteExpense(String eventId, String expenseId) async
    test('test deleteExpense', () async {
      // TODO
    });

    // Détail d'une dépense : payeur, participants, part de chacun.
    //
    //Future<ExpenseDetail> getExpense(String eventId, String expenseId) async
    test('test getExpense', () async {
      // TODO
    });

    // Dépenses de l'événement, avec les totaux.
    //
    //Future<ExpensesPage> listExpenses(String eventId) async
    test('test listExpenses', () async {
      // TODO
    });

    // Modifie une dépense. L'état précédent est conservé.
    //
    //Future<ExpenseDetail> updateExpense(String eventId, String expenseId, ExpenseBody expenseBody) async
    test('test updateExpense', () async {
      // TODO
    });

  });
}

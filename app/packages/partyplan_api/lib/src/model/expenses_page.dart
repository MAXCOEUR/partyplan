//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/expense_list_item.dart';
import 'package:built_collection/built_collection.dart';
import 'package:partyplan_api/src/model/balance_view_amount.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'expenses_page.g.dart';

/// Totaux affichés en tête de liste.
///
/// Properties:
/// * [total] 
/// * [myShare] 
/// * [items] 
@BuiltValue()
abstract class ExpensesPage implements Built<ExpensesPage, ExpensesPageBuilder> {
  @BuiltValueField(wireName: r'total')
  BalanceViewAmount get total;

  @BuiltValueField(wireName: r'myShare')
  BalanceViewAmount get myShare;

  @BuiltValueField(wireName: r'items')
  BuiltList<ExpenseListItem> get items;

  ExpensesPage._();

  factory ExpensesPage([void updates(ExpensesPageBuilder b)]) = _$ExpensesPage;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ExpensesPageBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ExpensesPage> get serializer => _$ExpensesPageSerializer();
}

class _$ExpensesPageSerializer implements PrimitiveSerializer<ExpensesPage> {
  @override
  final Iterable<Type> types = const [ExpensesPage, _$ExpensesPage];

  @override
  final String wireName = r'ExpensesPage';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ExpensesPage object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'total';
    yield serializers.serialize(
      object.total,
      specifiedType: const FullType(BalanceViewAmount),
    );
    yield r'myShare';
    yield serializers.serialize(
      object.myShare,
      specifiedType: const FullType(BalanceViewAmount),
    );
    yield r'items';
    yield serializers.serialize(
      object.items,
      specifiedType: const FullType(BuiltList, [FullType(ExpenseListItem)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ExpensesPage object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ExpensesPageBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'total':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BalanceViewAmount),
          ) as BalanceViewAmount;
          result.total.replace(valueDes);
          break;
        case r'myShare':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BalanceViewAmount),
          ) as BalanceViewAmount;
          result.myShare.replace(valueDes);
          break;
        case r'items':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(ExpenseListItem)]),
          ) as BuiltList<ExpenseListItem>;
          result.items.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ExpensesPage deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ExpensesPageBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}



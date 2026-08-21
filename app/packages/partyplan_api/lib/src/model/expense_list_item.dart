//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/balance_view_amount.dart';
import 'package:partyplan_api/src/model/admin_list_users_page_parameter.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'expense_list_item.g.dart';

/// Dépense dans la liste (EF-DEP-04).
///
/// Properties:
/// * [id] 
/// * [label] 
/// * [amount] 
/// * [paidByMemberId] 
/// * [paidByDisplayName] 
/// * [spentAt] 
/// * [participantCount] 
/// * [fromShoppingItem] 
@BuiltValue()
abstract class ExpenseListItem implements Built<ExpenseListItem, ExpenseListItemBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'label')
  String get label;

  @BuiltValueField(wireName: r'amount')
  BalanceViewAmount get amount;

  @BuiltValueField(wireName: r'paidByMemberId')
  String get paidByMemberId;

  @BuiltValueField(wireName: r'paidByDisplayName')
  String get paidByDisplayName;

  @BuiltValueField(wireName: r'spentAt')
  DateTime get spentAt;

  @BuiltValueField(wireName: r'participantCount')
  AdminListUsersPageParameter get participantCount;

  @BuiltValueField(wireName: r'fromShoppingItem')
  bool get fromShoppingItem;

  ExpenseListItem._();

  factory ExpenseListItem([void updates(ExpenseListItemBuilder b)]) = _$ExpenseListItem;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ExpenseListItemBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ExpenseListItem> get serializer => _$ExpenseListItemSerializer();
}

class _$ExpenseListItemSerializer implements PrimitiveSerializer<ExpenseListItem> {
  @override
  final Iterable<Type> types = const [ExpenseListItem, _$ExpenseListItem];

  @override
  final String wireName = r'ExpenseListItem';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ExpenseListItem object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'label';
    yield serializers.serialize(
      object.label,
      specifiedType: const FullType(String),
    );
    yield r'amount';
    yield serializers.serialize(
      object.amount,
      specifiedType: const FullType(BalanceViewAmount),
    );
    yield r'paidByMemberId';
    yield serializers.serialize(
      object.paidByMemberId,
      specifiedType: const FullType(String),
    );
    yield r'paidByDisplayName';
    yield serializers.serialize(
      object.paidByDisplayName,
      specifiedType: const FullType(String),
    );
    yield r'spentAt';
    yield serializers.serialize(
      object.spentAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'participantCount';
    yield serializers.serialize(
      object.participantCount,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'fromShoppingItem';
    yield serializers.serialize(
      object.fromShoppingItem,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ExpenseListItem object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ExpenseListItemBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'label':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.label = valueDes;
          break;
        case r'amount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BalanceViewAmount),
          ) as BalanceViewAmount;
          result.amount.replace(valueDes);
          break;
        case r'paidByMemberId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.paidByMemberId = valueDes;
          break;
        case r'paidByDisplayName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.paidByDisplayName = valueDes;
          break;
        case r'spentAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.spentAt = valueDes;
          break;
        case r'participantCount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.participantCount.replace(valueDes);
          break;
        case r'fromShoppingItem':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.fromShoppingItem = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ExpenseListItem deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ExpenseListItemBuilder();
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



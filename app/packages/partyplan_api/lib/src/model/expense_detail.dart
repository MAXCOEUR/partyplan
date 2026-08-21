//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/expense_share_view.dart';
import 'package:built_collection/built_collection.dart';
import 'package:partyplan_api/src/model/balance_view_amount.dart';
import 'package:partyplan_api/src/model/admin_list_users_page_parameter.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'expense_detail.g.dart';

/// Détail d'une dépense (EF-DEP-05).
///
/// Properties:
/// * [id] 
/// * [label] 
/// * [amount] 
/// * [paidByMemberId] 
/// * [paidByDisplayName] 
/// * [spentAt] 
/// * [fromShoppingItem] 
/// * [revisionCount] 
/// * [shares] 
@BuiltValue()
abstract class ExpenseDetail implements Built<ExpenseDetail, ExpenseDetailBuilder> {
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

  @BuiltValueField(wireName: r'fromShoppingItem')
  bool get fromShoppingItem;

  @BuiltValueField(wireName: r'revisionCount')
  AdminListUsersPageParameter get revisionCount;

  @BuiltValueField(wireName: r'shares')
  BuiltList<ExpenseShareView> get shares;

  ExpenseDetail._();

  factory ExpenseDetail([void updates(ExpenseDetailBuilder b)]) = _$ExpenseDetail;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ExpenseDetailBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ExpenseDetail> get serializer => _$ExpenseDetailSerializer();
}

class _$ExpenseDetailSerializer implements PrimitiveSerializer<ExpenseDetail> {
  @override
  final Iterable<Type> types = const [ExpenseDetail, _$ExpenseDetail];

  @override
  final String wireName = r'ExpenseDetail';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ExpenseDetail object, {
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
    yield r'fromShoppingItem';
    yield serializers.serialize(
      object.fromShoppingItem,
      specifiedType: const FullType(bool),
    );
    yield r'revisionCount';
    yield serializers.serialize(
      object.revisionCount,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'shares';
    yield serializers.serialize(
      object.shares,
      specifiedType: const FullType(BuiltList, [FullType(ExpenseShareView)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ExpenseDetail object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ExpenseDetailBuilder result,
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
        case r'fromShoppingItem':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.fromShoppingItem = valueDes;
          break;
        case r'revisionCount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.revisionCount.replace(valueDes);
          break;
        case r'shares':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(ExpenseShareView)]),
          ) as BuiltList<ExpenseShareView>;
          result.shares.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ExpenseDetail deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ExpenseDetailBuilder();
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



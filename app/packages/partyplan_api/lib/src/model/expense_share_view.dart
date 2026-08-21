//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/balance_view_amount.dart';
import 'package:partyplan_api/src/model/admin_list_users_page_parameter.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'expense_share_view.g.dart';

/// Participant à une dépense, tel que l'interface l'affiche.
///
/// Properties:
/// * [memberId] 
/// * [displayName] 
/// * [share] 
/// * [amount] 
@BuiltValue()
abstract class ExpenseShareView implements Built<ExpenseShareView, ExpenseShareViewBuilder> {
  @BuiltValueField(wireName: r'memberId')
  String get memberId;

  @BuiltValueField(wireName: r'displayName')
  String get displayName;

  @BuiltValueField(wireName: r'share')
  AdminListUsersPageParameter get share;

  @BuiltValueField(wireName: r'amount')
  BalanceViewAmount get amount;

  ExpenseShareView._();

  factory ExpenseShareView([void updates(ExpenseShareViewBuilder b)]) = _$ExpenseShareView;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ExpenseShareViewBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ExpenseShareView> get serializer => _$ExpenseShareViewSerializer();
}

class _$ExpenseShareViewSerializer implements PrimitiveSerializer<ExpenseShareView> {
  @override
  final Iterable<Type> types = const [ExpenseShareView, _$ExpenseShareView];

  @override
  final String wireName = r'ExpenseShareView';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ExpenseShareView object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'memberId';
    yield serializers.serialize(
      object.memberId,
      specifiedType: const FullType(String),
    );
    yield r'displayName';
    yield serializers.serialize(
      object.displayName,
      specifiedType: const FullType(String),
    );
    yield r'share';
    yield serializers.serialize(
      object.share,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'amount';
    yield serializers.serialize(
      object.amount,
      specifiedType: const FullType(BalanceViewAmount),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ExpenseShareView object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ExpenseShareViewBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'memberId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.memberId = valueDes;
          break;
        case r'displayName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.displayName = valueDes;
          break;
        case r'share':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.share.replace(valueDes);
          break;
        case r'amount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BalanceViewAmount),
          ) as BalanceViewAmount;
          result.amount.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ExpenseShareView deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ExpenseShareViewBuilder();
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



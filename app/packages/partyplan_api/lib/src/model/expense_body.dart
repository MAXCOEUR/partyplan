//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:partyplan_api/src/model/share_body.dart';
import 'package:partyplan_api/src/model/balance_view_amount.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'expense_body.g.dart';

/// ExpenseBody
///
/// Properties:
/// * [label] 
/// * [amount] 
/// * [paidByMemberId] 
/// * [spentAt] 
/// * [mode] 
/// * [shares] 
@BuiltValue()
abstract class ExpenseBody implements Built<ExpenseBody, ExpenseBodyBuilder> {
  @BuiltValueField(wireName: r'label')
  String get label;

  @BuiltValueField(wireName: r'amount')
  BalanceViewAmount get amount;

  @BuiltValueField(wireName: r'paidByMemberId')
  String? get paidByMemberId;

  @BuiltValueField(wireName: r'spentAt')
  DateTime? get spentAt;

  @BuiltValueField(wireName: r'mode')
  String? get mode;

  @BuiltValueField(wireName: r'shares')
  BuiltList<ShareBody>? get shares;

  ExpenseBody._();

  factory ExpenseBody([void updates(ExpenseBodyBuilder b)]) = _$ExpenseBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ExpenseBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ExpenseBody> get serializer => _$ExpenseBodySerializer();
}

class _$ExpenseBodySerializer implements PrimitiveSerializer<ExpenseBody> {
  @override
  final Iterable<Type> types = const [ExpenseBody, _$ExpenseBody];

  @override
  final String wireName = r'ExpenseBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ExpenseBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
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
    yield object.paidByMemberId == null ? null : serializers.serialize(
      object.paidByMemberId,
      specifiedType: const FullType.nullable(String),
    );
    yield r'spentAt';
    yield object.spentAt == null ? null : serializers.serialize(
      object.spentAt,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'mode';
    yield object.mode == null ? null : serializers.serialize(
      object.mode,
      specifiedType: const FullType.nullable(String),
    );
    yield r'shares';
    yield object.shares == null ? null : serializers.serialize(
      object.shares,
      specifiedType: const FullType.nullable(BuiltList, [FullType(ShareBody)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ExpenseBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ExpenseBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
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
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.paidByMemberId = valueDes;
          break;
        case r'spentAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.spentAt = valueDes;
          break;
        case r'mode':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.mode = valueDes;
          break;
        case r'shares':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(ShareBody)]),
          ) as BuiltList<ShareBody>?;
          if (valueDes == null) continue;
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
  ExpenseBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ExpenseBodyBuilder();
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



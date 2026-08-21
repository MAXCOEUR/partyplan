//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/balance_view_amount.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'mark_settlement_body.g.dart';

/// MarkSettlementBody
///
/// Properties:
/// * [fromMemberId] 
/// * [toMemberId] 
/// * [amount] 
@BuiltValue()
abstract class MarkSettlementBody implements Built<MarkSettlementBody, MarkSettlementBodyBuilder> {
  @BuiltValueField(wireName: r'fromMemberId')
  String get fromMemberId;

  @BuiltValueField(wireName: r'toMemberId')
  String get toMemberId;

  @BuiltValueField(wireName: r'amount')
  BalanceViewAmount get amount;

  MarkSettlementBody._();

  factory MarkSettlementBody([void updates(MarkSettlementBodyBuilder b)]) = _$MarkSettlementBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(MarkSettlementBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<MarkSettlementBody> get serializer => _$MarkSettlementBodySerializer();
}

class _$MarkSettlementBodySerializer implements PrimitiveSerializer<MarkSettlementBody> {
  @override
  final Iterable<Type> types = const [MarkSettlementBody, _$MarkSettlementBody];

  @override
  final String wireName = r'MarkSettlementBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    MarkSettlementBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'fromMemberId';
    yield serializers.serialize(
      object.fromMemberId,
      specifiedType: const FullType(String),
    );
    yield r'toMemberId';
    yield serializers.serialize(
      object.toMemberId,
      specifiedType: const FullType(String),
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
    MarkSettlementBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required MarkSettlementBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'fromMemberId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.fromMemberId = valueDes;
          break;
        case r'toMemberId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.toMemberId = valueDes;
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
  MarkSettlementBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = MarkSettlementBodyBuilder();
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


